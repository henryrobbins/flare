(harness-codex)=
# Codex

The Codex harness runs OpenAI's
[Codex](https://chatgpt.com/codex) CLI inside the `FLARE` Docker
container, billing usage against your ChatGPT subscription via OAuth
credentials stored in `~/.codex`.

## Choosing a plan

Codex is available on paid ChatGPT plans. Compare plans at
[ChatGPT pricing](https://chatgpt.com/pricing/) and pick one that
covers your expected usage, then monitor your consumption at
[Analytics](https://chatgpt.com/codex/cloud/settings/analytics).

## Authenticating for FLARE

Authenticate the Codex CLI on the host following
[these instructions](https://developers.openai.com/codex/auth/ci-cd-auth):

```bash
codex login
```

This writes credentials to `~/.codex`. `FLARE` bind-mounts that
directory read-write into the Docker container at run time so Codex
can refresh its access token mid-session.

## Using the harness

```python
from milp_flare.harness import CodexHarness

harness = CodexHarness(model="gpt-5.4", effort="high")
```

Or via the `HARNESSES` registry (convenient for config-driven
experiment scripts):

```python
from milp_flare import HARNESSES

harness = HARNESSES["codex"](model="gpt-5.4", effort="high")
```

## Cost tracking

The Codex CLI does not report per-run USD, so the harness computes it from token totals using the pricing table in {data}`COST_PER_MTOK <milp_flare.harness.cost.COST_PER_MTOK>`. This is used to populate `cost_usd` in {class}`HarnessRunResult <milp_flare.harness.base.HarnessRunResult>`. Ensure the pricing table reflects current OpenAI API prices.
