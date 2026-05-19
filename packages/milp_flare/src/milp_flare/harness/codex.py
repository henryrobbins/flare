import json
import shutil
from pathlib import Path
from typing import Any

from milp_flare.assets import SCRIPTS_DIR, SKILLS_DIR
from milp_flare.harness.base import Harness

_TEMPLATE: str = (SCRIPTS_DIR / "codex_agent.sh").read_text()


class CodexHarness(Harness):
    """FLARE harness backed by the Codex CLI.

    Authenticates by bind-mounting ``~/.codex`` (populated via
    ``codex login``) read-write into the container so Codex can refresh
    its access token mid-session. Skill bundles are copied to
    ``wd/.agents/skills/``; MCP configuration is handled inline in
    ``codex_agent.sh``.

    Parameters
    ----------
    config : HarnessConfig
        Shared model and reasoning configuration. ``model`` must be an
        OpenAI model identifier (e.g., ``"gpt-5.4"``).

    Examples
    --------
    Drive FLARE with GPT-5.4 at high reasoning effort::

        >>> from milp_flare import FLARE, HarnessConfig
        >>> from milp_flare.harness import CodexHarness
        >>> harness = CodexHarness(
        ...     HarnessConfig(model="gpt-5.4", reasoning_effort="high")
        ... )
        >>> flare = FLARE(harness=harness)
    """

    name = "codex"

    def configure_wd(self, wd: Path) -> None:
        super().configure_wd(wd)
        # MCP server configuration is handled in the agent command:
        #   milp_flare/assets/scripts/codex_agent.sh
        # Copy skills to .agents/skills
        # https://developers.openai.com/codex/skills#where-to-save-skills
        agents_skills = wd / ".agents" / "skills"
        agents_skills.parent.mkdir(exist_ok=True)
        shutil.copytree(SKILLS_DIR, agents_skills, dirs_exist_ok=True)

    def _agent_docker_args(self) -> list[str]:
        # We use this authentication strategy instead of an API key to avoid the
        # higher API costs compared a ChatGPT subscription
        # Mount rw because codex refreshes its access token mid-session
        # https://developers.openai.com/codex/auth/ci-cd-auth
        codex_dir = Path.home() / ".codex"
        if not codex_dir.exists():
            raise RuntimeError("codex harness requires ~/.codex from `codex login`")
        return ["-v", f"{codex_dir}:/home/agent/.codex"]

    def _agent_command(self) -> str:
        # Pass model and effort to the agent command template
        return _TEMPLATE.replace("<<MODEL>>", self.model).replace(
            "<<EFFORT>>", self.effort
        )

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        """Parse `codex exec --json` output."""
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
            it = (
                usage.get("input_tokens")
                or usage.get("inputTokens")
                or usage.get("prompt_tokens")
                or 0
            )
            ot = (
                usage.get("output_tokens")
                or usage.get("outputTokens")
                or usage.get("completion_tokens")
                or 0
            )
            if isinstance(it, int):
                input_tokens += it
            if isinstance(ot, int):
                output_tokens += ot
            sr = event.get("stop_reason") or event.get("finish_reason")
            if isinstance(sr, str):
                stop_reason = sr

        return {
            "stop_reason": stop_reason,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": None,
        }
