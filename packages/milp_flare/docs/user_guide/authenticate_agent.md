# Agent Harness Authentication

FLARE ships three agent harnesses — Claude Code, Codex, and OpenCode.
Pick the one you plan to use and authenticate it once on the host;
FLARE forwards the credentials into the container. For configuring a
harness in code, see {doc}`configure_harness`.

## Claude Code

```bash
claude setup-token
```

Save the printed token to a `.env` file in your project as

```
CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...
```

The token bills against your Claude.ai plan rather than the API.

## Codex

```bash
codex login
```

This writes credentials to `~/.codex`. The Codex harness bind-mounts
that directory read-write so Codex can refresh its access token
mid-session.

## OpenCode

OpenCode reads provider API keys from the environment. Export one or
more of:

```bash
export ANTHROPIC_API_KEY=...
export OPENAI_API_KEY=...
export GOOGLE_API_KEY=...
export DEEPSEEK_API_KEY=...
```

The matching key is forwarded into the container.
