"""`milp-flare` CLI entry point."""

from __future__ import annotations

import argparse
import subprocess
import sys

from milp_flare._assets import BUILD_CONTEXT, DOCKERFILE
from milp_flare.harness.base import IMAGE


def build_image(tag: str, no_cache: bool) -> int:
    cmd = ["docker", "build", "-f", str(DOCKERFILE), "-t", tag]
    if no_cache:
        cmd.append("--no-cache")
    cmd.append(str(BUILD_CONTEXT))
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd).returncode


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="milp-flare")
    sub = parser.add_subparsers(dest="command", required=True)

    build = sub.add_parser(
        "build-image",
        help="Build the agent Docker image from the bundled Dockerfile.",
    )
    build.add_argument(
        "--tag",
        default=IMAGE,
        help=f"Image tag (default: {IMAGE}).",
    )
    build.add_argument(
        "--no-cache",
        action="store_true",
        help="Pass --no-cache to docker build.",
    )

    args = parser.parse_args(argv)

    if args.command == "build-image":
        return build_image(args.tag, args.no_cache)
    parser.error(f"unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
