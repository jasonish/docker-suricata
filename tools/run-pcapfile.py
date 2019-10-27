#! /usr/bin/env python3

import sys
import os
import argparse
import subprocess

DEFAULT_DOCKER_IMAGE = "jasonish/suricata:master"

EPILOG = """
Extra arguments can be passed to Suricata with --: For example:

    ./run-pcapfile.py -r input.pcap -- --no-checksum
"""

def ferror(msg):
    print("error: {}".format(msg), file=sys.stderr)
    sys.exit(1)

def main():

    parser = argparse.ArgumentParser(
        epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument(
        "-l", metavar="DIR", default=".", dest="logdir",
        help="Log directory (default = current directory)")

    parser.add_argument(
        "-r", metavar="FILE", default=None, dest="pcapfile",
        help="PCAP file to read")

    parser.add_argument(
        "-v", metavar="VOL", default=[], nargs="+", dest="volumes",
        help="Additional volumes")

    parser.add_argument(
        "--image", metavar="NAME", default=DEFAULT_DOCKER_IMAGE, dest="image",
        help="Name of docker image (default: {})".format(DEFAULT_DOCKER_IMAGE))

    parser.add_argument(
        "remainder", nargs=argparse.REMAINDER, help=argparse.SUPPRESS)

    args = parser.parse_args()
    print(args)

    docker_args = [
        "docker",
        "run",
        "--rm",
        "-it",
    ]

    for volume in args.volumes:
        src, target = volume.split(":", 1)
        abs_src = os.path.abspath(src)
        docker_args.append("--volume={}:{}".format(abs_src, target))

    suricata_args = []

    docker_args += [
        "-e", "PUID=%d" % os.getuid(),
        "-e", "PGID=%d" % os.getgid(),
    ]

    if not args.logdir:
        args.logdir = "."
    abs_logdir = os.path.abspath(args.logdir)
    docker_args.append("--volume={}:/work/output".format(abs_logdir))
    suricata_args += ["-l", "/work/output"]

    if not os.path.exists(abs_logdir):
        os.makedirs(abs_logdir)

    if not args.pcapfile:
        ferror("error: -r required (a pcap file)")
    abs_pcapfile = os.path.abspath(args.pcapfile)
    docker_args.append("--volume={}:/input.pcap".format(abs_pcapfile))

    docker_args += [
        args.image,
        "/usr/bin/suricata",
        "-r", "/input.pcap",
    ]

    docker_args += suricata_args

    if args.remainder:
        docker_args += args.remainder[1:]
        
    print("Running: %s" % (str(docker_args)))
    subprocess.call(docker_args)

if __name__ == "__main__":
    sys.exit(main())
