import json
import os
import shutil
from pathlib import Path
from typing import Any

from milp_flare.harness.base import Harness

_TEMPLATE: str = (
    Path(__file__).parent / "agent_commands" / "claude_code_agent.sh"
).read_text()


class ClaudeCodeHarness(Harness):
    name = "claude_code"

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        super().configure_wd(wd, repo_root)
        # Copy MCP server configuration (passed to --mcp-config)
        # https://code.claude.com/docs/en/mcp#project-scope
        shutil.copy2(repo_root / ".mcp.json", wd / ".mcp.json")
        # Copy skills to .claude/skills
        # https://code.claude.com/docs/en/skills#where-skills-live
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            claude_skills = wd / ".claude" / "skills"
            claude_skills.parent.mkdir(exist_ok=True)
            shutil.copytree(skills_src, claude_skills, dirs_exist_ok=True)

    def _agent_docker_args(self) -> list[str]:
        # We use a long-lived token here instead of an API key to avoid the
        # higher API costs compared a Claude Code subscription
        # https://code.claude.com/docs/en/authentication#generate-a-long-lived-token
        if "CLAUDE_CODE_OAUTH_TOKEN" not in os.environ:
            raise RuntimeError(
                "claude_code harness requires CLAUDE_CODE_OAUTH_TOKEN"
                " from `claude setup-token`"
            )
        return ["-e", "CLAUDE_CODE_OAUTH_TOKEN"]

    def _agent_command(self) -> str:
        # Pass model and effort to the agent command template
        return _TEMPLATE.replace("<<MODEL>>", self.model).replace(
            "<<EFFORT>>", self.effort
        )

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        """Parse `claude -p --output-format stream-json` output."""
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
