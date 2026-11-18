"""Offline tests: python3 -m unittest discover -s .github/scripts -v"""

import argparse
import contextlib
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import security_refresh_monitor as monitor


def finding(package="openssl-libs", cve="CVE-2026-0001", severity="HIGH", fixed="2.0-1"):
    return {
        "PkgName": package, "VulnerabilityID": cve, "Severity": severity,
        "InstalledVersion": "1.0-1", "FixedVersion": fixed,
    }


def scan_document(findings=(), version="1.0", family="alma", packages=True):
    return {
        "SchemaVersion": 2,
        "Metadata": {"OS": {"Family": family, "Name": "9.7"}},
        "Results": [{
            "Class": "os-pkgs", "Type": "alma",
            "Packages": [{"Name": "openssl-libs", "Version": version, "Release": "1", "Arch": "x86_64"}] if packages else [],
            "Vulnerabilities": list(findings),
        }],
    }


class MonitorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.before = self.root / "before.json"
        self.after = self.root / "after.json"
        self.write(self.before, scan_document([finding()]))
        self.write(self.after, scan_document(version="2.0"))

    def write(self, path, document):
        path.write_text(json.dumps(document))

    def compare(self):
        return monitor.compare_scans(self.before, self.after)

    def test_fixed_finding_would_publish(self):
        decision = self.compare()
        self.assertEqual(decision["decision"], "would_publish")
        self.assertEqual(len(decision["fixed"]), 1)

    def test_low_severity_fix_qualifies(self):
        self.write(self.before, scan_document([finding(severity="LOW")]))
        self.assertEqual(self.compare()["decision"], "would_publish")

    def test_unchanged_findings_do_not_publish(self):
        self.write(self.after, scan_document([finding()]))
        self.assertEqual(self.compare()["decision"], "would_not_publish")

    def test_digest_or_package_change_alone_is_not_enough(self):
        self.write(self.before, scan_document())
        self.assertEqual(self.compare()["decision"], "would_not_publish")

    def test_equal_counts_do_not_hide_regression(self):
        self.write(self.after, scan_document([finding(cve="CVE-2026-0002")], version="2.0"))
        decision = self.compare()
        self.assertEqual(decision["decision"], "would_not_publish")
        self.assertEqual(len(decision["fixed"]), 1)
        self.assertEqual(len(decision["blocking"]), 1)

    def test_new_unfixed_critical_finding_also_blocks(self):
        self.write(self.after, scan_document([finding(cve="CVE-2026-0002", severity="CRITICAL", fixed="")], version="2.0"))
        self.assertEqual(self.compare()["decision"], "would_not_publish")

    def test_new_low_finding_is_reported_but_does_not_block(self):
        self.write(self.after, scan_document([finding(cve="CVE-2026-0002", severity="LOW")], version="2.0"))
        decision = self.compare()
        self.assertEqual(decision["decision"], "would_publish")
        self.assertEqual(len(decision["introduced"]), 1)

    def test_unfixed_finding_disappearance_is_not_a_trigger(self):
        self.write(self.before, scan_document([finding(fixed="")]))
        self.assertEqual(self.compare()["decision"], "would_not_publish")

    def test_disappearance_without_package_upgrade_is_inconclusive(self):
        self.write(self.after, scan_document())
        with self.assertRaisesRegex(ValueError, "Cannot verify package upgrade"):
            self.compare()

    def test_removed_package_requires_human_review(self):
        document = scan_document(version="2.0")
        document["Results"][0]["Packages"][0]["Name"] = "different-package"
        self.write(self.after, document)
        with self.assertRaisesRegex(ValueError, "Cannot verify package upgrade"):
            self.compare()

    def test_missing_inventory_is_not_clean(self):
        self.write(self.after, scan_document(packages=False))
        with self.assertRaisesRegex(ValueError, "missing OS-package inventory"):
            self.compare()

    def test_wrong_distro_is_not_clean(self):
        self.write(self.after, scan_document(family="debian"))
        with self.assertRaisesRegex(ValueError, "AlmaLinux 9"):
            self.compare()

    def test_missing_os_result_is_not_clean(self):
        document = scan_document()
        document["Results"] = []
        self.write(self.after, document)
        with self.assertRaises(ValueError):
            self.compare()

    def test_null_vulnerabilities_is_valid(self):
        document = scan_document(version="2.0")
        document["Results"][0]["Vulnerabilities"] = None
        self.write(self.after, document)
        self.assertEqual(self.compare()["decision"], "would_publish")

    def test_release_version(self):
        self.assertEqual(monitor.release_version("This is Suricata version 8.0.7 RELEASE", "8.0"), "8.0.7")
        for version in ("This is Suricata version 9.0.0-dev", "This is Suricata version 8.0.9-dev", "unknown", "7.0.17"):
            with self.assertRaises(ValueError):
                monitor.release_version(version, "8.0")

    def fake_args(self):
        work = self.root / "work"
        db = work / "trivy-cache" / "db"
        db.mkdir(parents=True)
        (db / "metadata.json").write_text("{}")
        (db / "trivy.db").write_bytes(b"test database")
        return argparse.Namespace(series="8.0", arch="amd64", variant="regular", work_dir=work, output=self.root)

    def exercise_monitor(self, no_findings=False):
        args = self.fake_args()
        info = {"Id": "sha256:baseline", "RepoDigests": ["example@sha256:digest"]}
        commands = []
        scans = []

        def fake_run(*command, **kwargs):
            commands.append(tuple(str(c) for c in command))
            return "test-trivy-version"

        def fake_scan(image, destination, cache, arch):
            scans.append((image, cache, arch))
            document = scan_document(version="2.0") if image == "sha256:candidate" else scan_document([] if no_findings else [finding()])
            self.write(destination, document)

        with patch.object(monitor, "run", side_effect=fake_run), \
             patch.object(monitor, "pull", return_value=info), \
             patch.object(monitor, "inspect_image", return_value={"Id": "sha256:candidate"}), \
             patch.object(monitor, "image_command", return_value="This is Suricata version 8.0.7 RELEASE"), \
             patch.object(monitor, "scan", side_effect=fake_scan):
            report = {}
            monitor.monitor(args, report)
        return report, commands, scans

    def test_no_findings_skips_build(self):
        report, commands, scans = self.exercise_monitor(no_findings=True)
        self.assertEqual(report["decision"], "would_not_publish")
        self.assertFalse(any(c[:2] == ("docker", "build") for c in commands))
        self.assertEqual(len(scans), 1)

    def test_candidate_uses_published_version_and_shared_database(self):
        report, commands, scans = self.exercise_monitor()
        self.assertEqual(report["decision"], "would_publish")
        build = next(c for c in commands if c[:2] == ("docker", "build"))
        self.assertIn("VERSION=8.0.7", build)
        self.assertIn("--no-cache", build)
        self.assertEqual(scans[0][1], scans[1][1])
        self.assertFalse(any("push" in c or "login" in c for c in commands))
        self.assertIn("FROM example@sha256:digest AS runner", (self.root / "Dockerfile.pinned").read_text())

    def test_scan_disables_db_updates_and_keeps_unfixed_findings(self):
        with patch.object(monitor, "run") as run:
            monitor.scan("image-id", self.before, self.root, "arm64")
        command = run.call_args.args
        self.assertIn("--skip-db-update", command)
        self.assertIn("--list-all-pkgs", command)
        self.assertNotIn("--ignore-unfixed", command)
        self.assertIn("linux/arm64", command)

    def test_failure_produces_inconclusive_report_and_nonzero_exit(self):
        argv = ["monitor", "--series", "8.0", "--arch", "amd64", "--variant", "regular", "--work-dir", str(self.root), "--output", str(self.root)]
        with patch("sys.argv", argv), \
             patch.object(monitor, "monitor", side_effect=subprocess.CalledProcessError(1, ["trivy"])), \
             patch.dict("os.environ", {"GITHUB_STEP_SUMMARY": str(self.root / "job-summary")}), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            status = monitor.main()
        self.assertEqual(status, 1)
        self.assertEqual(json.loads((self.root / "decision.json").read_text())["decision"], "inconclusive")
        self.assertIn("::warning::", output.getvalue())
        self.assertIn("INCONCLUSIVE", (self.root / "job-summary").read_text())


if __name__ == "__main__":
    unittest.main()
