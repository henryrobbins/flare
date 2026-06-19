# Modal

`FLARE` can run agents in [Modal](https://modal.com/) Sandboxes instead of local Docker containers. Each agent runs in its own cloud Sandbox, which avoids duplicate [Lean](https://lean-lang.org/) environments and lets many agents run in parallel without consuming local resources.

## Install Modal

Modal support is an optional extra. Install it alongside `milp-flare`:

```bash
pip install milp-flare[modal]
```

Then authenticate the `modal` CLI against your Modal workspace (this writes a token to `~/.modal.toml`):

```bash
modal setup
```

Verify the credentials are working with:

```bash
modal app list
```

## Build Agent Image

`FLARE` runs agents from a named Modal image called `flare-agent`, the cloud counterpart of the local `flare-agent` Docker image. The `milp-flare` package provides a CLI for building and publishing it to your Modal workspace. This is expected to take ~5 minutes on the first build.

```bash
milp-flare build-modal-image
```

The image is published under the name `flare-agent` and associated with the `flare` Modal app (override with `--name` and `--app`; force a rebuild past Modal's layer cache with `--force`). Run `modal app list` and inspect the workspace's images to confirm it was published successfully.

The Modal image is built with Modal's Python SDK builder rather than the bundled `Dockerfile` (for better caching and faster iteration), but is kept in sync with it. It contains the same agent CLIs (Claude Code, Codex, OpenCode), the `elan` + Lean toolchain, the [lean-lsp-mcp](https://github.com/oOo0oOo/lean-lsp-mcp) MCP server, and the necessary Lean definitions in `Common.lean` (the same used by {fb}`/definitions.html`). Two notable differences from the Docker image: the Modal image runs as root with all tools installed globally, and it has no `ENTRYPOINT` — the runner invokes `run-agent` explicitly after the working directory is populated. See the build definition below.

:::{dropdown} `build-modal-image`
:icon: code
```{literalinclude} ../../src/milp_flare/__main__.py
:language: python
:pyobject: build_modal_image
```
:::

## Using the Modal Runner

A harness runs on local Docker by default. Pass a {class}`~milp_flare.harness.runner.modal.ModalRunner` to run on Modal instead:

```python
from milp_flare import FLARE
from milp_flare.harness import ClaudeCodeHarness
from milp_flare.harness.runner import ModalRunner

harness = ClaudeCodeHarness(
    model="claude-opus-4-7",
    effort="medium",
    runner=ModalRunner(),
)
flare = FLARE(harness=harness)
```

Everything else — including the call to `FLARE.verify` — is identical to the Docker workflow (see {doc}`run_flare`).

## Modal Resources

{class}`~milp_flare.harness.runner.modal.ModalRunner` exposes the per-Sandbox resource allocation as constructor arguments:

```python
ModalRunner(cpu=4.0, memory=4096, timeout=1800)
```

`cpu` is a guaranteed floor of cores (the Sandbox may burst higher), `memory` is in MiB, and `timeout` is a hard cap on Sandbox lifetime in seconds. Each Sandbox runs a single agent; to run agents in parallel, launch multiple runs and Modal provisions a Sandbox for each. See the {doc}`/api/runner` reference for the full set of options.

:::{note}
Running on Modal incurs cloud compute charges billed by your Modal workspace. See [Modal's pricing](https://modal.com/pricing) for details.
:::
