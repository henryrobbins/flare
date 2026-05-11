"""Docker-based agent harness.

Spins up a container per pair and dispatches one of claude_code | codex |
opencode via the image's entrypoint. The container is the isolation
boundary: the host pair_dir/wd is bind-mounted at /workspace, so the
agent's cwd, the lake project root, and the locations the entrypoint
writes outputs to (agent_output.jsonl, result.json, compile_log.txt)
all coincide at that single path. The heavy /workspace/.lake/ build tree
is shadowed by a named volume seeded from the image so mathlib oleans
never land on the host.

Image is built from the repo root Dockerfile. See AGENTS.md for setup.
"""

import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar

from src.llm_client import LLMConfig, compute_cost_usd

LAKE_VOLUME = "flare-lake"


@dataclass
class HarnessRunResult:
    duration_s: float
    cost_usd: float | None
    input_tokens: int
    output_tokens: int
    stop_reason: str | None


def _infer_provider(model: str) -> str:
    if model.startswith("claude"):
        return "anthropic"
    if model.startswith("deepseek"):
        return "deepseek"
    if model.startswith("gemini"):
        return "google"
    return "openai"


class Harness(ABC):
    cli: ClassVar[str]

    def __init__(
        self,
        config: LLMConfig,
        provider: str | None = None,
        image: str = "flare-agent:latest",
    ) -> None:
        self.config = config
        self.model = config.model
        self.effort = config.reasoning_effort or "medium"
        self.provider = provider or _infer_provider(config.model)
        self.image = image

    @property
    def name(self) -> str:
        return f"docker_{self.cli}"

    def method_config(self) -> dict:
        return {
            "harness": self.name,
            "cli": self.cli,
            "image": self.image,
            "provider": self.provider,
            "model": self.model,
            "effort": self.effort,
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature,
            "reasoning": self.config.reasoning,
            "reasoning_effort": self.config.reasoning_effort,
        }

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        # wd is bind-mounted directly to /workspace inside the container,
        # so anything written here is the agent's cwd at runtime.
        # Subclasses override and call super() to add their own settings
        # / skills / config files alongside agent.sh.
        wd.mkdir(parents=True, exist_ok=True)
        (wd / "agent.sh").write_text(self._agent_command())

    def run(self, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        # Bind: pair_dir/wd -> /workspace (agent cwd + lake project root +
        # where entrypoint writes outputs).
        # Named volume: flare-lake -> /workspace/.lake (shadows the bind
        # mount; seeded from the image's pre-built mathlib oleans on
        # first use, so .lake/ never touches the host filesystem).
        cmd = [
            "docker",
            "run",
            "--rm",
            "-v",
            f"{wd.resolve()}:/workspace",
            "-v",
            f"{LAKE_VOLUME}:/workspace/.lake",
        ]
        cmd += self._docker_args(wd)
        cmd += [self.image]

        start = time.time()
        # The entrypoint streams agent stdout to /workspace/agent_output.jsonl,
        # which is jsonl_path on the host (via the bind mount). We just need to
        # wait for the container and capture stderr for debugging.
        proc = subprocess.run(cmd, capture_output=True, text=True)
        duration = time.time() - start

        if proc.stderr:
            jsonl_path.with_name(f"{self.cli}_stderr.txt").write_text(proc.stderr)

        parsed = self._parse_stream(jsonl_path)
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self.model, parsed["input_tokens"], parsed["output_tokens"]
            )
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)

    @abstractmethod
    def _docker_args(self, wd: Path) -> list[str]:
        """CLI-specific `docker run` args (env passthroughs + bind mounts)."""
        ...

    @abstractmethod
    def _agent_command(self) -> str:
        """Bash script that invokes the agent CLI and streams its JSONL output
        to /workspace/agent_output.jsonl. Rendered into wd/agent.sh and
        sourced by the container entrypoint."""
        ...

    def _parse_stream(self, jsonl_path: Path) -> dict:
        if not jsonl_path.exists():
            return {
                "stop_reason": None,
                "input_tokens": 0,
                "output_tokens": 0,
                "cost_usd": None,
            }
        return self._parse_lines(jsonl_path.read_text().splitlines())

    @abstractmethod
    def _parse_lines(self, lines: list[str]) -> dict: ...
