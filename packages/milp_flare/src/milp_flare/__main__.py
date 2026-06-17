"""`milp-flare` CLI entry point."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from milp_flare._assets import BUILD_CONTEXT, DOCKERFILE, MODAL_DOCKERFILE
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


def build_modal_image(name: str, app_name: str, force: bool) -> int:
    """Build the root-based agent image on Modal and publish it as `name`.

    Reuses the same context-staging trick as :func:`build_image` (dereferencing
    symlinks so `assets/lean/*` resolve in a dev checkout), then builds
    ``Dockerfile.modal`` on Modal and publishes the result as a named image that
    Sandboxes reference via ``modal.Image.from_name(name)``.
    """
    try:
        import modal
    except ModuleNotFoundError:
        print(
            "the modal compute backend requires the `modal` package; "
            "install it with `pip install milp-flare[modal]`",
            file=sys.stderr,
        )
        return 1

    with tempfile.TemporaryDirectory() as tmp:
        ctx = Path(tmp) / "context"
        shutil.copytree(BUILD_CONTEXT, ctx, symlinks=False)
        dockerfile = ctx / MODAL_DOCKERFILE.relative_to(BUILD_CONTEXT)

        app = modal.App.lookup(name=app_name, create_if_missing=True)
        image = modal.Image.from_dockerfile(
            str(dockerfile),
            context_dir=str(ctx),
            force_build=force,
        )
        with modal.enable_output():
            built = image.build(app)
        built.publish(name)

    print(f"Published Modal image '{name}' (app '{app_name}').")
    print("Reference it from a Sandbox with:")
    print(f"    modal.Image.from_name({name!r})")
    return 0


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

    build_modal = sub.add_parser(
        "build-modal-image",
        help="Build and publish the agent image on Modal as a named image.",
    )
    build_modal.add_argument(
        "--name",
        default="flare-agent",
        help="Name to publish the Modal image under (default: flare-agent).",
    )
    build_modal.add_argument(
        "--app",
        default="flare",
        help="Modal app to associate the image build with (default: flare).",
    )
    build_modal.add_argument(
        "--force",
        action="store_true",
        help="Force a rebuild even if Modal has cached layers.",
    )

    args = parser.parse_args(argv)

    if args.command == "build-image":
        return build_image(args.tag, args.no_cache)
    if args.command == "build-modal-image":
        return build_modal_image(args.name, args.app, args.force)
    parser.error(f"unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    sys.exit(main())
