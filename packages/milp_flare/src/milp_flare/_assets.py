"""Paths to bundled package assets.

These point at files under ``milp_flare/assets/`` that ship with the
installed package (declared in ``[tool.setuptools.package-data]``).
"""

from pathlib import Path

_ASSETS_DIR = Path(__file__).parent / "assets"

# Minimal Lean / Lake skeleton copied into each agent working directory:
# Common.lean, lakefile.toml, lean-toolchain, lake-manifest.json.
LEAN_DIR = _ASSETS_DIR / "lean"

# Skill bundles passed to the in-container agent (claude-code reads from
# wd/.claude/skills; codex and opencode read from wd/.agents/skills).
SKILLS_DIR = _ASSETS_DIR / "skills"

# MCP server configuration for the claude_code harness (copied to wd/.mcp.json).
MCP_JSON = _ASSETS_DIR / "configs" / "mcp.json"

# Jinja2 templates for prompts rendered by `milp_flare._prompts`.
PROMPTS_DIR = _ASSETS_DIR / "prompts"

# Per-harness agent launch scripts sourced by the container entrypoint.
SCRIPTS_DIR = _ASSETS_DIR / "scripts"

# Dockerfile + entrypoint for the agent image. `DOCKER_DIR` lives inside
# `_ASSETS_DIR` so the Dockerfile's COPY paths resolve against `_ASSETS_DIR`
# as the build context (see `milp_flare.__main__:build_image`).
DOCKER_DIR = _ASSETS_DIR / "docker"
DOCKERFILE = DOCKER_DIR / "Dockerfile"

# The Modal compute backend builds its image programmatically (see
# `milp_flare.__main__:build_modal_image`) rather than from a Dockerfile, so
# there is no Modal-specific Dockerfile asset.

# Build context for `docker build` — the parent of `lean/` and `docker/`.
BUILD_CONTEXT = _ASSETS_DIR
