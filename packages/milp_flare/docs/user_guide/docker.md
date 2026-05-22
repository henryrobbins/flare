# Setting up Docker

FLARE runs each agent inside a Linux container, so a working Docker
installation is a hard requirement.

## Install Docker

Install Docker and ensure the daemon is running. Verify with:

```bash
docker info
```

## Build the agent image

The `milp-flare` CLI builds the `flare-agent:latest` image from a
Dockerfile bundled with the package:

```bash
milp-flare build-image
```

The image bakes the agent CLIs (Claude Code, Codex, OpenCode), the
Lean-LSP MCP server, and a Lake-built Lean environment with Mathlib
pre-compiled (~5 minutes cold; ~1 s when only the entrypoint changed).
Rebuild after a `lean-toolchain` bump:

```bash
milp-flare build-image --no-cache
```

## How the container is used at runtime

At runtime FLARE bind-mounts a per-pair working directory into the
container at `/workspace/wd` and symlinks `.lake` from the image-baked
location into that directory. The Lean environment is never copied to
the host, and each pair gets an isolated build cache via container
copy-on-write — runs are safe to parallelize.
