import json
import os
import shutil
from pathlib import Path
from typing import Any

from milp_flare._assets import SCRIPTS_DIR, SKILLS_DIR
from milp_flare.harness.base import Harness

_TEMPLATE: str = (SCRIPTS_DIR / "opencode_agent.sh").read_text()


def _infer_provider(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("gemini"):
        return "google"
    return "openai"


class OpenCodeHarness(Harness):
    """OpenCode agent harness for FLARE.

    Use the :opencode:`OpenCode CLI </>` as an agent harness. Authentication is
    provided by API key. The following API keys are automatically forwarded from
    the host into the container if they are set:

    - ``ANTHROPIC_API_KEY`` for Anthropic models
    - ``OPENAI_API_KEY`` for OpenAI models
    - ``GOOGLE_API_KEY`` for Google models
    - ``DEEPSEEK_API_KEY`` for DeepSeek models

    See :ref:`harness-opencode` for setup instructions.

    Parameters
    ----------
    model : str
        Model identifier passed to the underlying CLI. See
        :opencode:`/providers` for supported providers and models.
    effort : str, default ``"medium"``
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``). Supported
        reasoning effort levels vary by provider and model.
    provider : str, optional
        The OpenCode model provider to use. By default, the provider is inferred
        from the model name. See :opencode:`/providers` for supported providers.

    Attributes
    ----------
    name : str
        Name of the agent harness: ``"opencode"``.
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.
    provider : str
        Resolved provider name this harness is configured to use.

    Examples
    --------
    Configure OpenCode agent harness with DeepSeek V4 Pro and high effort::

        >>> from milp_flare import FLARE
        >>> from milp_flare.harness import OpenCodeHarness
        >>> harness = OpenCodeHarness(model="deepseek-v4-pro", effort="high")
        >>> print(json.dumps(harness.get_config_dict(), indent=2))
        {
          "harness": "opencode",
          "image": "flare-agent:latest",
          "model": "deepseek-v4-pro",
          "effort": "high",
          "provider": "deepseek"
        }
    """

    name = "opencode"

    def __init__(
        self,
        model: str,
        effort: str = "medium",
        provider: str | None = None,
    ) -> None:
        super().__init__(model, effort)
        self.provider = provider or _infer_provider(model)

    def get_config_dict(self) -> dict[str, Any]:
        return {**super().get_config_dict(), "provider": self.provider}

    def configure_wd(self, wd: Path) -> None:
        super().configure_wd(wd)
        # Use an `opencode.json` file to configure the model provider and MCP server
        # https://opencode.ai/docs/config/
        (wd / "opencode.json").write_text(json.dumps(self._opencode_config(), indent=2))
        # Copy skills to .agents/skills
        # https://opencode.ai/docs/skills/#place-files
        agents_skills = wd / ".agents" / "skills"
        agents_skills.parent.mkdir(exist_ok=True)
        shutil.copytree(SKILLS_DIR, agents_skills, dirs_exist_ok=True)

    def _opencode_config(self) -> dict[str, Any]:
        """Minimal opencode.json to register the model and lean-lsp MCP server."""
        options: dict[str, Any]
        if self.provider == "anthropic":
            options = {
                "thinking": {"type": "adaptive"},
                "output_config": {"effort": self.effort},
            }
        else:
            options = {"reasoningEffort": self.effort}
        return {
            "$schema": "https://opencode.ai/config.json",
            # https://opencode.ai/docs/providers/
            "provider": {self.provider: {"models": {self.model: {"options": options}}}},
            # https://opencode.ai/docs/mcp-servers
            "mcp": {
                "lean-lsp": {
                    "type": "local",
                    "command": ["uvx", "lean-lsp-mcp"],
                    "enabled": True,
                }
            },
        }

    def _agent_docker_args(self) -> list[str]:
        # Pass through any available provider API key
        args: list[str] = []
        for key in (
            "ANTHROPIC_API_KEY",
            "OPENAI_API_KEY",
            "GOOGLE_API_KEY",
            "DEEPSEEK_API_KEY",
        ):
            if key in os.environ:
                args += ["-e", key]
        return args

    def _agent_command(self) -> str:
        # Pass model and provider to the agent command template
        return _TEMPLATE.replace("<<PROVIDER>>", self.provider).replace(
            "<<MODEL>>", self.model
        )

    def _parse_lines(self, lines: list[str]) -> dict[str, Any]:
        """Parse `opencode run --format json` output."""
        input_tokens = 0
        output_tokens = 0
        cost_usd: float | None = None
        stop_reason: str | None = None

        def _as_int(x: Any) -> int:
            return x if isinstance(x, int) else 0

        for line in lines:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") != "step_finish":
                continue
            part = event.get("part") or {}
            tokens = part.get("tokens") or {}
            cache = tokens.get("cache") or {}
            input_tokens += (
                _as_int(tokens.get("input"))
                + _as_int(cache.get("write"))
                + _as_int(cache.get("read"))
            )
            output_tokens += _as_int(tokens.get("output"))
            c = part.get("cost")
            if isinstance(c, (int, float)):
                cost_usd = (cost_usd or 0.0) + float(c)
            r = part.get("reason")
            if isinstance(r, str):
                stop_reason = r

        return {
            "stop_reason": stop_reason,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cost_usd": cost_usd,
        }
