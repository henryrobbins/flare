(harness-opencode)=
# OpenCode

The [OpenCode](https://opencode.ai/) harness runs the OpenCode CLI
inside the `FLARE` Docker container. Unlike Claude Code and Codex,
OpenCode bills directly against an API provider (Anthropic, OpenAI,
Google, or DeepSeek) rather than a flat-rate subscription.

## Choosing an API provider

OpenCode supports multiple providers. Sign up for an API account with your chosen provider, fund it, and monitor consumption from the provider's usage dashboard. The example below uses
[DeepSeek](https://api-docs.deepseek.com/quick_start/pricing) which can be monitored [here](https://platform.deepseek.com/usage).

## Authenticating for FLARE

OpenCode reads provider API keys from the environment. Export the key
matching your chosen provider (see
[OpenCode providers](https://opencode.ai/docs/providers/) for the full
list). For example:

```bash
export DEEPSEEK_API_KEY=...
```

Other supported keys: `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`,
`GOOGLE_API_KEY`.

`FLARE` forwards the matching key into the Docker container at run time.

## Using the harness

The {class}`OpenCodeHarness <milp_flare.harness.opencode.OpenCodeHarness>` infers the provider from the model name. You can pass `provider` to override.

```python
from milp_flare.harness import OpenCodeHarness

harness = OpenCodeHarness(
    model="deepseek-chat", effort="medium", provider="deepseek"
)
```

Or via the `HARNESSES` registry (convenient for config-driven
experiment scripts):

```python
from milp_flare import HARNESSES

harness = HARNESSES["opencode"](
    model="deepseek-chat", effort="medium", provider="deepseek"
)
```

## Cost tracking

The OpenCode CLI reports a per-step cost for each provider call; the harness sums these into `cost_usd` in {class}`HarnessRunResult <milp_flare.harness.base.HarnessRunResult>`.
