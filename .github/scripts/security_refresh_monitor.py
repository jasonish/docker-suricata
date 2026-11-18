#!/usr/bin/env python3
"""Observe security-refresh opportunities. Deliberately has no publish operation."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


BLOCKING_SEVERITIES = {"HIGH", "CRITICAL"}


def read_scan(path):
    """Reject empty/unsupported scans instead of treating them as clean images."""
    data = json.loads(Path(path).read_text())
    distro = data.get("Metadata", {}).get("OS", {})
    if distro.get("Family") != "alma" or distro.get("Name", "").split(".")[0] != "9":
        raise ValueError(f"{path}: expected a detected AlmaLinux 9 image")
    results = [r for r in data.get("Results", []) if r.get("Class") == "os-pkgs"]
    if len(results) != 1 or results[0].get("Type") != "alma":
        raise ValueError(f"{path}: expected one AlmaLinux OS-package result")
    packages = {}
    for package in results[0].get("Packages", []):
        identity = tuple(str(package.get(k, "")) for k in ("Epoch", "Version", "Release", "Arch"))
        packages.setdefault(package["Name"], set()).add(identity)
    if not packages:
        raise ValueError(f"{path}: missing OS-package inventory")
    findings = {}
    for finding in results[0].get("Vulnerabilities") or []:
        key = (finding["PkgName"], finding["VulnerabilityID"])
        if key[0] not in packages:
            raise ValueError(f"{path}: finding missing from package inventory: {key}")
        findings[key] = finding
    return findings, packages


def finding_details(key, finding):
    return {
        "package": key[0],
        "vulnerability": key[1],
        "severity": finding.get("Severity", "UNKNOWN"),
        "installed_version": finding.get("InstalledVersion", ""),
        "fixed_version": finding.get("FixedVersion", ""),
    }


def compare_scans(before_path, after_path):
    before, old_packages = read_scan(before_path)
    after, new_packages = read_scan(after_path)
    fixed = []
    for key in sorted(before.keys() - after.keys()):
        if not before[key].get("FixedVersion"):
            continue
        # A disappeared finding alone isn't enough: the affected package must
        # still be detected, with a changed version. Removals need human review.
        if key[0] not in new_packages or old_packages[key[0]] == new_packages[key[0]]:
            raise ValueError(f"Cannot verify package upgrade for disappeared finding {key}")
        fixed.append(finding_details(key, before[key]))
    introduced = [finding_details(k, after[k]) for k in sorted(after.keys() - before.keys())]
    blocking = [f for f in introduced if f["severity"] in BLOCKING_SEVERITIES]
    if blocking:
        reason = "Candidate introduces HIGH/CRITICAL OS-package findings."
    elif not fixed:
        reason = "Candidate fixes no known-fixable OS-package findings."
    else:
        reason = "Candidate fixes OS-package findings with no new HIGH/CRITICAL findings."
    return {
        "decision": "would_publish" if fixed and not blocking else "would_not_publish",
        "reason": reason,
        "fixed": fixed,
        "introduced": introduced,
        "blocking": blocking,
    }


def run(*args, capture=True):
    print("+ " + " ".join(str(a) for a in args), flush=True)
    result = subprocess.run([str(a) for a in args], text=True, stdout=subprocess.PIPE if capture else None)
    if result.returncode:
        if capture and result.stdout:
            print(result.stdout, flush=True)
        raise subprocess.CalledProcessError(result.returncode, args)
    return result.stdout.strip() if capture else ""


def inspect_image(reference, arch):
    info = json.loads(run("docker", "image", "inspect", reference))[0]
    if info.get("Architecture") != arch or info.get("Os") != "linux":
        raise ValueError(f"Unexpected platform for {reference}")
    return info


def pull(reference, arch):
    run("docker", "pull", "--platform", f"linux/{arch}", reference, capture=False)
    info = inspect_image(reference, arch)
    if not info.get("RepoDigests"):
        raise ValueError(f"No registry digest for {reference}")
    return info


def image_command(image, executable, *args):
    return run(
        "docker", "run", "--rm", "--network", "none", "--read-only",
        "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
        "--entrypoint", executable, image, *args,
    )


def release_version(output, series):
    match = re.search(r"\bSuricata version (\d+\.\d+\.\d+)(?=\s|$)", output)
    if not match or not match[1].startswith(series + "."):
        raise ValueError(f"Expected a stable Suricata {series} release, got: {output}")
    return match[1]


def scan(image, destination, cache, arch):
    run(
        "trivy", "image", "--cache-dir", cache,
        "--image-src", "docker", "--platform", f"linux/{arch}",
        "--scanners", "vuln", "--pkg-types", "os", "--list-all-pkgs",
        "--skip-db-update", "--skip-java-db-update", "--exit-code", "0",
        "--timeout", "15m", "--format", "json", "--output", destination, image,
        capture=False,
    )
    read_scan(destination)


def monitor(args, report):
    suffix = "-profiling" if args.variant == "profiling" else ""
    reference = f"docker.io/jasonish/suricata:{args.series}{suffix}"
    baseline = pull(reference, args.arch)
    report["baseline"] = {
        "tag": reference, "digest": baseline["RepoDigests"][0], "image_id": baseline["Id"],
    }
    cache = args.work_dir / "trivy-cache"
    run("trivy", "image", "--cache-dir", cache, "--download-db-only", capture=False)
    # The baseline and candidate scans use this exact DB, with updates disabled.
    metadata = cache / "db" / "metadata.json"
    shutil.copyfile(metadata, args.output / "trivy-db-metadata.json")
    report["trivy_version"] = run("trivy", "--cache-dir", cache, "--version")
    database = cache / "db" / "trivy.db"
    with database.open("rb") as stream:
        report["database_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
    before_path = args.output / "before.json"
    scan(baseline["Id"], before_path, cache, args.arch)
    before, _ = read_scan(before_path)
    report["baseline_findings"] = len(before)
    report["baseline_fixable_findings"] = sum(bool(f.get("FixedVersion")) for f in before.values())
    if not report["baseline_fixable_findings"]:
        report.update(decision="would_not_publish", reason="No known-fixable OS-package findings; candidate build skipped.")
        return

    # Rebuild the *published* release, not a newer VERSION from this checkout.
    # This avoids attributing a Suricata release upgrade to an OS refresh.
    version = release_version(image_command(baseline["Id"], "/usr/bin/suricata", "-V"), args.series)
    report["suricata_version"] = version
    context = Path(args.series)
    dockerfile = (context / f"Dockerfile.{args.arch}").read_text()
    bases = []

    def pin_base(match):
        base = pull(match[1], args.arch)
        digest = base["RepoDigests"][0]
        bases.append({"tag": match[1], "digest": digest, "image_id": base["Id"], "stage": match[2]})
        return f"FROM {digest} AS {match[2]}"

    pinned, count = re.subn(r"^FROM (\S+) AS (builder|runner)$", pin_base, dockerfile, flags=re.MULTILINE)
    if count != 2:
        raise ValueError("Expected exactly one builder and one runner base image")
    report["candidate_bases"] = bases
    pinned_path = args.output / "Dockerfile.pinned"
    pinned_path.write_text(pinned)
    candidate_tag = f"security-refresh-monitor:{args.series}-{args.arch}-{args.variant}"
    configure_args = "--enable-profiling --enable-profiling-locks" if args.variant == "profiling" else ""
    run(
        "docker", "build", "--pull", "--no-cache", "--platform", f"linux/{args.arch}",
        "--build-arg", f"VERSION={version}", "--build-arg", f"CORES={os.cpu_count() or 2}",
        "--build-arg", f"CONFIGURE_ARGS={configure_args}",
        "--tag", candidate_tag, "--file", pinned_path, context, capture=False,
    )
    candidate = inspect_image(candidate_tag, args.arch)
    report["candidate_image_id"] = candidate["Id"]
    candidate_version = release_version(image_command(candidate["Id"], "/usr/bin/suricata", "-V"), args.series)
    if candidate_version != version:
        raise ValueError("Candidate Suricata version differs from published version")
    build_info = image_command(candidate["Id"], "/usr/bin/suricata", "--build-info")
    (args.output / "candidate-build-info.txt").write_text(build_info + "\n")
    report["smoke_test"] = "Suricata -V and --build-info passed"
    after_path = args.output / "after.json"
    scan(candidate["Id"], after_path, cache, args.arch)
    report.update(compare_scans(before_path, after_path))


def write_report(output, report):
    (output / "decision.json").write_text(json.dumps(report, indent=2) + "\n")
    label = report["decision"].replace("_", " ").upper()
    scope = f"{report['series']} / {report['arch']} / {report['variant']}"
    lines = [
        f"## Security refresh: {scope}", "", f"**{label} (dry run)**", "",
        report["reason"], "",
        "No registry login or publishing was performed. This is a per-image recommendation, not a release approval.", "",
        "Policy: fix at least one known-fixable OS-package finding (any severity), with no new HIGH/CRITICAL findings.",
        "A base-digest change is not required: package-repository security fixes also qualify.", "",
    ]
    if "baseline" in report:
        lines += [f"Baseline: `{report['baseline']['digest']}`", ""]
    if "suricata_version" in report:
        lines += [f"Suricata version held at: `{report['suricata_version']}`", ""]
    for field, title in (("fixed", "Fixed findings"), ("introduced", "New findings")):
        findings = report.get(field, [])
        lines += [f"### {title}: {len(findings)}", ""]
        lines += [f"- {f['vulnerability']} — `{f['package']}` ({f['severity']})" for f in findings]
        lines.append("")
    lines += [
        "Coverage: AlmaLinux OS advisories only; not comprehensive EPEL or source-built application coverage.",
        "See the artifacts for scan reports, database identity, pinned bases, and the decision record.", "",
    ]
    summary = "\n".join(lines)
    (output / "summary.md").write_text(summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as stream:
            stream.write(summary)
    print(summary, flush=True)
    annotation = f"{scope}: {label} (dry run). {report['reason']} No images published."
    annotation = annotation.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    level = "warning" if report["decision"] == "inconclusive" else "notice"
    print(f"::{level}::{annotation}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--series", choices=("8.0",), required=True)
    parser.add_argument("--arch", choices=("amd64", "arm64"), required=True)
    parser.add_argument("--variant", choices=("regular", "profiling"), required=True)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.work_dir = args.work_dir.resolve()
    args.output = args.output.resolve()
    args.work_dir.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    report = {
        "series": args.series, "arch": args.arch, "variant": args.variant,
        "checkout": os.environ.get("GITHUB_SHA", "local"),
        "decision": "inconclusive", "reason": "Monitoring did not complete.",
    }
    status = 0
    try:
        monitor(args, report)
    except Exception as error:
        report.update(decision="inconclusive", reason=f"{type(error).__name__}: {error}")
        status = 1
    write_report(args.output, report)
    return status


if __name__ == "__main__":
    sys.exit(main())
