"""Harness for the `claude` CLI inside the Docker image."""

import json

from src.verify.flare.harness.base import Harness


class ClaudeCodeHarness(Harness):
    cli = "claude_code"

    def _credential_args(self) -> list[str]:
        # OAuth token from `claude setup-token`, exported in .env.
        return ["-e", "CLAUDE_CODE_OAUTH_TOKEN"]

    def _parse_lines(self, lines: list[str]) -> dict:
        """Parse `claude -p --output-format stream-json` output.

        Tokens, stop_reason, and total_cost_usd live on the final `result` event.
        """
        input_tokens = 0
        output_tokens = 0
        stop_reason: str | None = None
        cost_usd: float | None = None

        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("type") == "result":
                stop_reason = obj.get("stop_reason")
                cost_usd = obj.get("total_cost_usd")
                usage = obj.get("usage", {})
                input_tokens = usage.get("input_tokens", input_tokens)
                output_tokens = usage.get("output_tokens", output_tokens)

        return {"stop_reason": stop_reason, "input_tokens": input_tokens,
                "output_tokens": output_tokens, "cost_usd": cost_usd}
