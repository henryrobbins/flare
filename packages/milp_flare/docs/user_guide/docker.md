# Docker

`FLARE` uses Docker to isolate agent working directories and avoid duplicate [Lean](https://lean-lang.org/) environments when running multiple agents in parallel.

## Install Docker

Install either [Docker Desktop](https://docs.docker.com/desktop/) (recommended) or [Docker Engine](https://docs.docker.com/engine/). Both installations include the `docker` CLI. Verify the docker daemon is running with:

```bash
docker images
```

## Build Agent Image

`FLARE` runs agents inside Docker containers built from a standard base image called `flare-agent`. The `milp-flare` package provides a CLI for building the `flare-agent:latest` image from a `Dockerfile` bundled with the package. This is expected to take ~5 minutes on the first build.

```bash
milp-flare build-image
```

Run `docker images` to verify the `flare-agent` image was created successfully. The ~10GB size is mostly attributable to the [Mathlib](https://mathlib-initiative.org/) library.

```
$ docker images
REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
flare-agent   latest    8c164dafcbc3   26 hours ago   12GB
```

The image contains agent CLIs (Claude Code, Codex, OpenCode), the `elan` + Lean toolchain, the [lean-lsp-mcp](https://github.com/oOo0oOo/lean-lsp-mcp) MCP server, and the necessary Lean definitions in `Common.lean` (the same used by {fb}`/definitions.html`). See the `Dockerfile` below.

:::{dropdown} `assets/docker/Dockerfile`
:icon: code
```{literalinclude} ../../src/milp_flare/assets/docker/Dockerfile
:language: docker
```
:::

## Docker Resources

Docker allows the user to configure resource allocation. The minimum requirements for `FLARE` are 2 CPUs, 4GB memory, and 16GB disk usage. To run multiple agents in parallel, it is recommended to have ~2 CPUs and ~3GB memory per agent. Experiments from the {paper}`/` were performed on a MacBook Pro (Apple M3 Pro, 12-core CPU, 18 GB unified memory). 5 agents were comfortably run in parallel with a 10 CPU and 16GB resource allocation.

:::{warning}
It is not recommended to allocate *all* of your machine's computational resources is any category.
:::
