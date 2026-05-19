# Configuring an agent harness

FLARE ships three agent harnesses — Claude Code, Codex, and OpenCode.
All three implement the {class}`~milp_flare.harness.base.Harness`
interface, share the same {class}`~milp_flare.harness.config.HarnessConfig`
fields, and are swappable in `FLARE(harness=...)`.

## Common configuration

```python
from milp_flare import HarnessConfig

config = HarnessConfig(
    model="claude-opus-4-7",
    reasoning=True,
    reasoning_effort="high",  # "low" | "medium" | "high"
)
```

`reasoning` toggles extended reasoning; `reasoning_effort` is forwarded
to the underlying CLI/provider where supported. The harness's
`method_config()` dict (written to `runs/<id>/config.json`) records
the harness name, image tag, model, and effort.

## Claude Code

Uses a long-lived OAuth token instead of an API key so the run bills
against your Claude.ai subscription.

```python
from milp_flare import HarnessConfig
from milp_flare.harness import ClaudeCodeHarness

harness = ClaudeCodeHarness(
    HarnessConfig(model="claude-opus-4-7", reasoning_effort="medium")
)
```

Requires `CLAUDE_CODE_OAUTH_TOKEN` on the host (`claude setup-token`).
The MCP server configuration is copied to `wd/.mcp.json` and skills
are copied to `wd/.claude/skills/`.

## Codex

```python
from milp_flare import HarnessConfig
from milp_flare.harness import CodexHarness

harness = CodexHarness(
    HarnessConfig(model="gpt-5.4", reasoning_effort="high")
)
```

Requires `~/.codex` populated via `codex login`; FLARE bind-mounts it
read-write so Codex can refresh its access token. Skills are copied
to `wd/.agents/skills/`. The MCP server is configured inline in the
agent launch script.

## OpenCode

OpenCode supports multiple providers. The harness infers the provider
from the model name (`claude-*` → `anthropic`, `deepseek-*` →
`deepseek`, `gemini-*` → `google`, else `openai`); pass `provider=`
to override.

```python
from milp_flare import HarnessConfig
from milp_flare.harness import OpenCodeHarness

harness = OpenCodeHarness(
    HarnessConfig(model="gpt-5.4", reasoning=True, reasoning_effort="medium"),
    provider="openai",
)
```

Requires the matching provider API key in the environment
(`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY`, or
`DEEPSEEK_API_KEY`). A generated `opencode.json` is written to the
working directory; skills are copied to `wd/.agents/skills/`.

## Selecting a harness by name

The `HARNESSES` registry maps harness names to classes, which is
convenient for config-driven experiment scripts:

```python
from milp_flare import HARNESSES, HarnessConfig

harness_cls = HARNESSES["claude_code"]
harness = harness_cls(HarnessConfig(model="claude-opus-4-7"))
```

## Cost tracking

Each harness returns a `cost_usd` field on the run result. Claude Code
reports per-run USD directly; Codex computes it from token totals
using the pricing table in
{mod}`milp_flare.harness.config`; OpenCode sums per-step costs
reported by the CLI. Update the pricing table when provider prices
change.
