# Agent Harnesses

`FLARE` supports three agent harnesses. All three implement the
{class}`~milp_flare.harness.base.Harness` interface.

| Harness | Models | Billing | Credential |
| --- | --- | --- | --- |
| [Claude Code](claude_code.md) | Anthropic Claude | Claude subscription | `CLAUDE_CODE_OAUTH_TOKEN` (OAuth) |
| [Codex](codex.md) | OpenAI GPT | ChatGPT subscription | `~/.codex` (OAuth) |
| [OpenCode](opencode.md) | **All** Providers | Provider API | `<PROVIDER>_API_KEY` |

Each harness page covers:

1. **Choosing a plan** (or API account) — what to sign up for and where to track usage.
2. **Authentication** — the one-time setup step that allows `FLARE` to invoke the agent.
3. **Using the harness** — configuring the harness in Python for use by `FLARE`.
4. **Cost tracking** — how to track the cost of agent usage.

```{toctree}
:maxdepth: 1
:hidden:

claude_code
codex
opencode
```

