(harness-claude-code)=
# Claude Code

The Claude Code harness runs Anthropic's
[Claude Code](https://claude.com/claude-code) CLI inside the `FLARE` Docker
container, billing usage against your Claude subscription via a
long-lived OAuth token.

## Choosing a plan

Claude Code is included with every paid Claude plan. Compare plans
and pick one that covers your expected usage at
[Choose a Claude plan](https://support.claude.com/en/articles/11049762-choose-a-claude-plan),
then monitor your consumption at [Usage](https://claude.ai/settings/usage).

## Authenticating for FLARE

Generate a long-lived OAuth token following [these instructions](https://code.claude.com/docs/en/authentication#generate-a-long-lived-token):

```bash
claude setup-token
```

Save the printed token to a `.env` file in your project as:

```
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

`FLARE` forwards this token into the Docker container at run time. The token
bills against your Claude plan rather than the API.

:::{warning}
Starting June 15, 2026, Claude Agent SDK and `claude -p` usage no
longer count towards Claude plan usage limits. They will instead charge
a separate Agent SDK monthly credit. See
[this article](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan).
:::

## Using the harness

```python
from milp_flare.harness import ClaudeCodeHarness

harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="medium")
```

Or via the `HARNESSES` registry (convenient for config-driven
experiment scripts):

```python
from milp_flare import HARNESSES

harness = HARNESSES["claude_code"](model="claude-opus-4-7", effort="medium")
```

## Cost tracking

The Claude Code CLI JSON output stream reports per-run USD directly. This is used to populate `cost_usd` in {class}`HarnessRunResult <milp_flare.harness.base.HarnessRunResult>`.
