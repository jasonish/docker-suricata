#! /usr/bin/env python3

import sys
import os
import argparse

DEFAULT_IMAGE = "jasonish/suricata"
DEFAULT_TAG = "latest"


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--image", default=DEFAULT_IMAGE,
        help="Docker image (default: {})".format(DEFAULT_IMAGE))
    parser.add_argument(
        "--tag", default=DEFAULT_TAG,
        help="Docker image tag (default: {})".format(DEFAULT_TAG))
    parser.add_argument(
        "--net", default="host", help="Docker networking type (default: host)")
    parser.add_argument(
        "remainder", nargs=argparse.REMAINDER, help=argparse.SUPPRESS)
    parser.add_argument(
        "--podman", action="store_true", default=False, help="Use podman")
    parser.add_argument(
        "-e", "--env", action="append", default=[], help="Set environment variable")
    args = parser.parse_args()

    runner = "docker"
    if args.podman:
        runner = "podman"

    volumes = []

    user_mode = False
    log_dir = None

    suricata_args = []

    while args.remainder:
        arg = args.remainder.pop(0)
        if arg == "--":
            continue
        elif arg == "-S":
            v = args.remainder.pop(0)
            volumes += [
                "-v", "{}:{}".format(v, v)
            ]
            suricata_args += [arg, v]
        elif arg == "-r":
            v = args.remainder.pop(0)
            volumes += [
                "-v", "{}:{}".format(v, v)
            ]
            suricata_args += [arg, v]
            user_mode = True
        elif arg == "-l":
            v = args.remainder.pop(0)
            if not v.startswith("/"):
                v = "{}/{}".format(os.getcwd(), v)
            volumes += [
                "-v", "{}:/var/log/suricata".format(v)
            ]
            suricata_args += ["-l", "/var/log/suricata"]
            log_dir = v
        else:
            suricata_args += [arg]

    docker_args = [
        runner,
        "run",
        "--net", args.net,
        "--rm",
        "-it",
        "--cap-add", "sys_nice",
        "--cap-add", "net_admin",
        "-e", "PUID={}".format(getuid()),
        "-e", "PGID={}".format(getgid()),
    ]

    for e in args.env:
        docker_args += ["-e", e]

    if user_mode and log_dir is None:
        volumes += ["-v", "{}:/work".format(os.getcwd())]
        docker_args += ["-w", "/work"]

    docker_args += volumes

    docker_args += [
        "{}:{}".format(DEFAULT_IMAGE, args.tag)
    ]

    docker_args += suricata_args

    print(" ".join(docker_args))

    os.execvp(docker_args[0], docker_args)


def getuid():
    if os.getenv("SUDO_UID") != None:
        return os.getenv("SUDO_UID")
    return os.getuid()


def getgid():
    if os.getenv("SUDO_GID") != None:
        return os.getenv("SUDO_GID")
    return os.getgid()


if __name__ == "__main__":
    sys.exit(main())
