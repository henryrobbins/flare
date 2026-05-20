import json
import os
import shutil
from pathlib import Path
from typing import Any

from milp_flare._assets import MCP_JSON, SCRIPTS_DIR, SKILLS_DIR
from milp_flare.harness.base import Harness

_TEMPLATE: str = (SCRIPTS_DIR / "claude_code_agent.sh").read_text()


class ClaudeCodeHarness(Harness):
    """Claude Code agent harness for FLARE.

    Use the :claude:`Claude Code CLI </>` as an agent harness. Authentication
    is provided by a long-lived OAuth token (``CLAUDE_CODE_OAUTH_TOKEN``) generated
    via ``claude setup-token`` and is billed against a Claude subscription. See
    :ref:`harness-claude-code` for setup instructions.

    .. warning::

        Starting June 15, 2026, Claude Agent SDK and claude -p usage no longer
        counts towards the Claude plan's usage limits. It will instead charge a
        separate Agent SDK monthly credit. See
        `this article <https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan>`_.

    Parameters
    ----------
    model : str
        Claude model identifier. Only supports models that are supported by the
        Claude Code CLI (e.g., ``"claude-opus-4-7"``, ``"claude-sonnet-4-6"``).
        See :claude:`/model-config#model-aliases` for up-to-date model information.
    effort : str, default ``"medium"``
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``, ``"xhigh"``,
        ``"max"``). See :claude:`/model-config#choose-an-effort-level` for
        supported effort levels for each model.

    Attributes
    ----------
    name : str
        Name of the agent harness: ``"claude_code"``.
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.

    Examples
    --------
    Configure Claude Code agent harness with Claude Opus 4.7 and high effort::

        >>> from milp_flare import FLARE
        >>> from milp_flare.harness import ClaudeCodeHarness
        >>> harness = ClaudeCodeHarness(model="claude-opus-4-7", effort="high")
        >>> print(json.dumps(harness.get_config_dict(), indent=2))
        {
          "harness": "claude_code",
          "image": "flare-agent:latest",
          "model": "claude-opus-4-7",
          "effort": "high"
        }

    """

    name = "claude_code"

    def configure_wd(self, wd: Path) -> None:
        super().configure_wd(wd)
        # Copy MCP server configuration (passed to --mcp-config)
        # https://code.claude.com/docs/en/mcp#project-scope
        shutil.copy2(MCP_JSON, wd / ".mcp.json")
        # Copy skills to .claude/skills
        # https://code.claude.com/docs/en/skills#where-skills-live
        claude_skills = wd / ".claude" / "skills"
        claude_skills.parent.mkdir(exist_ok=True)
        shutil.copytree(SKILLS_DIR, claude_skills, dirs_exist_ok=True)

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
