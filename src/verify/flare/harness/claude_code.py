"""Harness for the `claude` CLI inside the Docker image."""

import json
import shutil
from pathlib import Path

from src.verify.flare.harness.base import Harness

_TEMPLATE: str = (
    Path(__file__).parent / "agent_commands" / "claude_code_agent.sh"
).read_text()


class ClaudeCodeHarness(Harness):
    cli = "claude_code"

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        super().configure_wd(wd, repo_root)
        # MCP server list is passed via --mcp-config in agent.sh, so no
        # .claude/settings.json is needed; skills are auto-discovered from
        # .claude/skills/.
        shutil.copy2(repo_root / ".mcp.json", wd / ".mcp.json")
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            claude_skills = wd / ".claude" / "skills"
            claude_skills.parent.mkdir(exist_ok=True)
            shutil.copytree(skills_src, claude_skills, dirs_exist_ok=True)

    def _docker_args(self, wd: Path) -> list[str]:
        # OAuth token from `claude setup-token`, exported in .env.
        return ["-e", "CLAUDE_CODE_OAUTH_TOKEN"]

    def _agent_command(self) -> str:
        return _TEMPLATE.replace("<<MODEL>>", self.model).replace(
            "<<EFFORT>>", self.effort
        )

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

        return {
            "stop_reason": stop_reason,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": cost_usd,
        }
