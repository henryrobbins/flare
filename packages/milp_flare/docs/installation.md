# Installation

## Install the package

```bash
pip install milp-flare
```

## Docker

FLARE runs each agent inside a Linux container, so a working Docker
installation is a hard requirement.

1. **Install Docker** and ensure the daemon is running. Verify with:

   ```bash
   docker info
   ```

2. **Build the agent image.** The `milp-flare` CLI builds the
   `flare-agent:latest` image from a Dockerfile bundled with the
   package:

   ```bash
   milp-flare build-image
   ```

   The image bakes the agent CLIs (Claude Code, Codex, OpenCode), the
   Lean-LSP MCP server, and a Lake-built Lean environment with Mathlib
   pre-compiled (~5 minutes cold; ~1 s when only the entrypoint
   changed). Rebuild after a `lean-toolchain` bump:

   ```bash
   milp-flare build-image --no-cache
   ```

At runtime FLARE bind-mounts a per-pair working directory into the
container at `/workspace/wd` and symlinks `.lake` from the image-baked
location into that directory. The Lean environment is never copied to
the host, and each pair gets an isolated build cache via container
copy-on-write — runs are safe to parallelize.

## Authenticate the coding agent

Pick the harness you plan to use and authenticate it once on the host;
FLARE forwards the credentials into the container.

### Claude Code

```bash
claude setup-token
```

Save the printed token to a `.env` file in your project as

```
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

The token bills against your Claude.ai plan rather than the API.

### Codex

```bash
codex login
```

This writes credentials to `~/.codex`. The Codex harness bind-mounts
that directory read-write so Codex can refresh its access token
mid-session.

### OpenCode

OpenCode reads provider API keys from the environment. Export one or
more of:

```bash
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...
export GOOGLE_API_KEY=...
export DEEPSEEK_API_KEY=...
```

The matching key is forwarded into the container.

## Quickstart

```python
from pathlib import Path

from milp_flare import FLARE, FormulationInput
from milp_flare.harness import ClaudeCodeHarness

harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="medium")
flare = FLARE(harness=harness)

a = FormulationInput(formulation_md=open("A.md").read(),
                     solve_py=open("A_solve.py").read())
b = FormulationInput(formulation_md=open("B.md").read(),
                     solve_py=open("B_solve.py").read())

result = flare.verify(a, b, output_path=Path("runs/example"))
print(result.is_reformulation, result.cost_usd)
```

See the {doc}`user_guide/index` for end-to-end tutorials.
