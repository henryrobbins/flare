"""`milp-flare` CLI entry point."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from milp_flare._assets import BUILD_CONTEXT, DOCKER_DIR, DOCKERFILE, LEAN_DIR
from milp_flare.harness.runner.base import IMAGE


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
    """Build and publish the Modal image via Modal's builder methods.

    The image is built with Modal's Python SDK to achieve better caching and
    faster iteration than the :meth:`Modal.Image.from_dockerfile` method
    provides. This should be kept in sync with the Dockerfile at
    ``assets/docker/Dockerfile``.

    There are two notable differences to the Dockerfile:
    - The Modal image runs as root and installs all tools globally.
    - The Modal image does not have an ENTRYPOINT.
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

    entrypoint = DOCKER_DIR / "entrypoint.sh"

    with tempfile.TemporaryDirectory() as tmp:
        # Stage only the Lean skeleton, dereferencing symlinks so the COPY-into
        # the image resolves in a dev checkout.
        lean_ctx = Path(tmp) / "lean"
        shutil.copytree(LEAN_DIR, lean_ctx, symlinks=False)

        app = modal.App.lookup(name=app_name, create_if_missing=True)
        image = (
            modal.Image.from_registry("ubuntu:24.04")
            .env({"DEBIAN_FRONTEND": "noninteractive"})
            # ripgrep is recommended for lean_local_search in lean-lsp-mcp.
            # `force_build=force` on the base layer so --force cascades through
            # every subsequent (cached) layer.
            .run_commands(
                "apt-get update && apt-get install -y --no-install-recommends "
                "ca-certificates curl git unzip build-essential python3 "
                "python3-pip pipx ripgrep procps && rm -rf /var/lib/apt/lists/*",
                force_build=force,
            )
            # Node 20 + agent CLIs (Claude Code, Codex, OpenCode), installed
            # globally.
            .run_commands(
                "curl -fsSL https://deb.nodesource.com/setup_20.x | bash - "
                "&& apt-get install -y --no-install-recommends nodejs "
                "&& npm install -g @anthropic-ai/claude-code @openai/codex "
                "opencode-ai && rm -rf /var/lib/apt/lists/*"
            )
            # elan + Lean toolchain in a global ELAN_HOME (not a user HOME) so
            # `lake`/`lean` are on PATH for root. `--default-toolchain none` lets
            # the lean-toolchain file pin the version on the first `lake` call.
            .env({"ELAN_HOME": "/opt/elan"})
            .run_commands(
                "curl https://raw.githubusercontent.com/leanprover/elan/master/"
                "elan-init.sh -sSf | sh -s -- -y --default-toolchain none "
                "--no-modify-path"
            )
            # pipx tools (lean-lsp-mcp, uv) to global dirs so their entrypoints
            # land on PATH regardless of user.
            .env({"PIPX_HOME": "/opt/pipx", "PIPX_BIN_DIR": "/usr/local/bin"})
            .run_commands("pipx install lean-lsp-mcp && pipx install uv")
            # Modal's .env() sets literal values and does not expand ${PATH} like
            # a Dockerfile ENV, so set an explicit PATH that puts /opt/elan/bin
            # ahead of the standard dirs (lake must resolve in the steps below).
            .env(
                {
                    "PATH": "/opt/elan/bin:/usr/local/sbin:/usr/local/bin:"
                    "/usr/sbin:/usr/bin:/sbin:/bin"
                }
            )
            .workdir("/workspace")
            # copy=True bakes the files into a build layer so the lake steps
            # below can read them (a non-copy add only mounts them at runtime).
            .add_local_dir(str(lean_ctx), "/workspace", copy=True)
            # Pre-fetch mathlib oleans for the pinned toolchain (also installs the
            # toolchain, since elan was set up with --default-toolchain none).
            .run_commands("lake exe cache get")
            # Pre-build Common so its olean is warm in /workspace/.lake/build/.
            .run_commands("lake build Common")
            # There is no ENTRYPOINT. The sandbox runner invokes
            # /usr/local/bin/run-agent explicitly after the working directory
            # has been populated.
            .add_local_file(str(entrypoint), "/usr/local/bin/run-agent", copy=True)
            .run_commands("chmod +x /usr/local/bin/run-agent")
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
