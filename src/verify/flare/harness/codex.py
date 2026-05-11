"""Harness for the `codex` CLI inside the Docker image."""

import json
from pathlib import Path

from src.verify.flare.harness.base import Harness

_TEMPLATE: str = (Path(__file__).parent / "templates" / "codex_agent.sh").read_text()


class CodexHarness(Harness):
    cli = "codex"

    def _docker_args(self, wd: Path) -> list[str]:
        # Bill against the ChatGPT subscription by mounting the host's cached
        # OAuth login (~/.codex/auth.json). Mount rw because codex refreshes
        # its access token mid-session; :ro breaks startup with "failed to
        # initialize in-process app-server client". OPENAI_API_KEY /
        # CODEX_API_KEY are deliberately NOT passed through so codex can't
        # fall through to API-key auth and bill against credits.
        codex_dir = Path.home() / ".codex"
        if not codex_dir.exists():
            raise RuntimeError(
                "codex harness requires ~/.codex from `codex login`"
            )
        return ["-v", f"{codex_dir}:/home/agent/.codex"]

    def _agent_script(self) -> str:
        return (_TEMPLATE
                .replace("<<MODEL>>", self.model)
                .replace("<<EFFORT>>", self.effort))

    def _parse_lines(self, lines: list[str]) -> dict:
        """Parse `codex exec --json` output: per-turn usage on `turn.completed`."""
        input_tokens = 0
        output_tokens = 0
        stop_reason: str | None = None

        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "turn.completed":
                continue
            usage = event.get("usage") or {}
            it = (usage.get("input_tokens") or usage.get("inputTokens")
                  or usage.get("prompt_tokens") or 0)
            ot = (usage.get("output_tokens") or usage.get("outputTokens")
                  or usage.get("completion_tokens") or 0)
            if isinstance(it, int):
                input_tokens += it
            if isinstance(ot, int):
                output_tokens += ot
            sr = event.get("stop_reason") or event.get("finish_reason")
            if isinstance(sr, str):
                stop_reason = sr

        return {"stop_reason": stop_reason, "input_tokens": input_tokens,
                "output_tokens": output_tokens, "cost_usd": None}
