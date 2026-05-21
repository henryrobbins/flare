"""`milp-flare` CLI entry point."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from milp_flare._assets import BUILD_CONTEXT, DOCKERFILE
from milp_flare.harness.base import IMAGE


def build_image(tag: str, no_cache: bool) -> int:
    # Stage the build context in a temp dir, dereferencing symlinks.
    # - In a dev checkout, files under `assets/lean/` are symlinks into the
    #   repo's `dataset/` which is outside the build context.
    # - In an installed package they are already real files.
    with tempfile.TemporaryDirectory() as tmp:
        ctx = Path(tmp) / "context"
        shutil.copytree(BUILD_CONTEXT, ctx, symlinks=False)
        dockerfile = ctx / DOCKERFILE.relative_to(BUILD_CONTEXT)
        cmd = ["docker", "build", "-f", str(dockerfile), "-t", tag]
        if no_cache:
            cmd.append("--no-cache")
        cmd.append(str(ctx))
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
