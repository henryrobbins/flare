"""Docker-based agent harness.

Spins up a container per pair and dispatches one of claude_code | codex |
opencode via the image's entrypoint. The container is the isolation boundary:
the host pair_dir is bind-mounted at /workspace/out, the agent works inside
/workspace/out/wd, and lake's build artifacts land in /workspace/.lake/
(image overlay, ephemeral). The entrypoint also runs the post-hoc
`lake env lean` compile inside the container and writes result.json back
through the bind mount.

Image is built from the repo root Dockerfile. See AGENTS.md for setup.
"""

import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import ClassVar

from src.llm_client import LLMConfig, compute_cost_usd


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
        # Per-pair files live at pair_dir = wd.parent; the entrypoint symlinks
        # everything in pair_dir into /workspace/ at runtime, so the agent's
        # cwd sees whatever each subclass writes here. The base only writes
        # agent.sh (the rendered CLI invocation); subclasses override and call
        # super() to add their own settings / skills / config files.
        pair_dir = wd.parent
        pair_dir.mkdir(parents=True, exist_ok=True)
        wd.mkdir(parents=True, exist_ok=True)
        (pair_dir / "agent.sh").write_text(self._agent_script())

    def run(self, wd: Path, jsonl_path: Path) -> HarnessRunResult:
        # The entrypoint sources /workspace/out/agent.sh (which the harness
        # rendered in configure_wd) and writes outputs (jsonl, result.json,
        # compile_log) into /workspace/out. A/, B/, Reformulation.lean are
        # bind-mounted directly so the agent sees them as real files
        # (claude_code's Write tool refuses symlinks).
        pair_dir = wd.parent
        cmd = [
            "docker", "run", "--rm",
            "-v", f"{pair_dir.resolve()}:/workspace/out",
            "-v", f"{(wd / 'A').resolve()}:/workspace/A",
            "-v", f"{(wd / 'B').resolve()}:/workspace/B",
            "-v", f"{(wd / 'Reformulation.lean').resolve()}:/workspace/Reformulation.lean",
        ]
        cmd += self._docker_args(wd)
        cmd += [self.image]

        start = time.time()
        # The entrypoint streams agent stdout to /workspace/out/agent_output.jsonl,
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
    def _agent_script(self) -> str:
        """Bash script that invokes the agent CLI and streams its JSONL output
        to /workspace/out/agent_output.jsonl. Rendered into pair_dir/agent.sh
        and sourced by the container entrypoint."""
        ...

    def _parse_stream(self, jsonl_path: Path) -> dict:
        if not jsonl_path.exists():
            return {"stop_reason": None, "input_tokens": 0, "output_tokens": 0,
                    "cost_usd": None}
        return self._parse_lines(jsonl_path.read_text().splitlines())

    @abstractmethod
    def _parse_lines(self, lines: list[str]) -> dict: ...
