"""Paths to bundled package assets.

These point at files under ``milp_flare/_assets/`` that ship with the
installed package (declared in ``[tool.setuptools.package-data]``).
"""

from pathlib import Path

_ASSETS_DIR = Path(__file__).parent / "_assets"

# Minimal Lean / Lake skeleton copied into each agent working directory:
# Common.lean, lakefile.toml, lean-toolchain, lake-manifest.json.
LEAN_DIR = _ASSETS_DIR / "lean"

# Skill bundles passed to the in-container agent (claude-code reads from
# wd/.claude/skills; codex and opencode read from wd/.agents/skills).
SKILLS_DIR = _ASSETS_DIR / "skills"

# MCP server configuration for the claude_code harness (copied to wd/.mcp.json).
MCP_JSON = _ASSETS_DIR / "mcp.json"

# Dockerfile + entrypoint for the agent image. `DOCKER_DIR` lives inside
# `_ASSETS_DIR` so the Dockerfile's COPY paths resolve against `_ASSETS_DIR`
# as the build context (see `milp_flare.__main__:build_image`).
DOCKER_DIR = _ASSETS_DIR / "docker"
DOCKERFILE = DOCKER_DIR / "Dockerfile"

# Build context for `docker build` — the parent of `lean/` and `docker/`.
BUILD_CONTEXT = _ASSETS_DIR
