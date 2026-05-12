import json
import os
import shutil
from pathlib import Path

from src.llm_client import LLMConfig
from src.verify.flare.harness.base import Harness

_TEMPLATE: str = (
    Path(__file__).parent / "agent_commands" / "opencode_agent.sh"
).read_text()


def _infer_provider(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("gemini"):
        return "google"
    return "openai"


class OpenCodeHarness(Harness):
    name = "opencode"

    def __init__(
        self,
        config: LLMConfig,
        provider: str | None = None,
    ) -> None:
        super().__init__(config)
        self.provider = provider or _infer_provider(config.model)

    def method_config(self) -> dict:
        return {**super().method_config(), "provider": self.provider}

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        super().configure_wd(wd, repo_root)
        # Use an `opencode.json` file to configure the model provider and MCP server
        # https://opencode.ai/docs/config/
        (wd / "opencode.json").write_text(json.dumps(self._opencode_config(), indent=2))
        # Copy skills to .agents/skills
        # https://opencode.ai/docs/skills/#place-files
        skills_src = repo_root / ".claude" / "skills"
        if skills_src.exists():
            agents_skills = wd / ".agents" / "skills"
            agents_skills.parent.mkdir(exist_ok=True)
            shutil.copytree(skills_src, agents_skills, dirs_exist_ok=True)

    def _opencode_config(self) -> dict:
        """Minimal opencode.json to register the model and lean-lsp MCP server."""
        options: dict = {}
        if self.config.temperature is not None:
            options["temperature"] = self.config.temperature
        if self.config.reasoning:
            if self.provider == "anthropic":
                options["thinking"] = {"type": "adaptive"}
                if self.config.reasoning_effort:
                    options["output_config"] = {"effort": self.config.reasoning_effort}
            elif self.config.reasoning_effort:
                options["reasoningEffort"] = self.config.reasoning_effort
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
        args = []
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

    def _parse_lines(self, lines: list[str]) -> dict:
        """Parse `opencode run --format json` output."""
        input_tokens = 0
        output_tokens = 0
        cost_usd: float | None = None
        stop_reason: str | None = None

        def _as_int(x) -> int:
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
