import os
import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

from milp_flare._llm import LLMConfig, compute_cost_usd


@dataclass
class HarnessRunResult:
    duration_s: float
    cost_usd: float | None
    input_tokens: int
    output_tokens: int
    stop_reason: str | None


IMAGE = "flare-agent:latest"


class Harness(ABC):
    name: ClassVar[str]

    def __init__(self, config: LLMConfig) -> None:
        self.config = config
        self.model = config.model
        self.effort = config.reasoning_effort or "medium"

    def method_config(self) -> dict[str, Any]:
        """Return the config dict that will be written to artifacts_dir/config.json."""
        return {
            "harness": self.name,
            "image": IMAGE,
            "model": self.model,
            "effort": self.effort,
            "max_tokens": self.config.max_tokens,
            "temperature": self.config.temperature,
            "reasoning": self.config.reasoning,
            "reasoning_effort": self.config.reasoning_effort,
        }

    def configure_wd(self, wd: Path) -> None:
        """Write all necessary files to the agent's working directory."""

        if not wd.exists():
            raise RuntimeError("The agent working directory hasn't been created yet.")

        # Add the agent command script to be called by the container entrypoint
        # See docker/entrypoint.sh
        (wd / "agent.sh").write_text(self._agent_command())

    def run(self, wd: Path) -> HarnessRunResult:

        # Print the path to the agent's JSONL output for easy monitoring in real time
        jsonl_path = wd / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        # Run the agent in a Docker container
        start = time.time()
        proc = subprocess.run(
            self._build_docker_cmd(wd),
            capture_output=True,
            text=True,
            # Without start_new_session, Ctrl+C in the terminal sends SIGINT to both
            # the driver and the agent container, which can cause the container to
            # terminate prematurely. start_new_session=True detaches the subprocess
            # from the terminal's process group.
            start_new_session=True,
        )
        duration = time.time() - start

        if proc.stderr:
            (wd / f"{self.name}_stderr.txt").write_text(proc.stderr)

        parsed = self._parse_stream(jsonl_path)
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self.model, parsed["input_tokens"], parsed["output_tokens"]
            )

        return HarnessRunResult(duration_s=round(duration, 1), **parsed)

    def _build_docker_cmd(self, wd: Path) -> list[str]:
        """Assemble the full `docker run` command for this harness."""
        cmd = ["docker", "run"]
        # Automatically remove the container when it exits
        cmd += ["--rm"]
        # Bind mount the agent's working directory to /workspace/wd in the container
        cmd += ["-v", f"{wd.resolve()}:/workspace/wd"]
        # Label the container with the FLARE run ID (if present)
        run_id = os.environ.get("FLARE_RUN_ID")
        if run_id:
            cmd += ["--label", f"flare-run={run_id}"]
        # Add any agent-specific docker args (env vars, additional mounts, etc.)
        cmd += self._agent_docker_args()
        # Finally, specify the image to run
        cmd += [IMAGE]
        return cmd

    @abstractmethod
    def _agent_docker_args(self) -> list[str]:
        """Agent-specific `docker run` args (env vars, additional mounts, etc.)."""
        ...

    @abstractmethod
    def _agent_command(self) -> str:
        """Command to invoke the agent and called by the container entrypoint."""
        ...

    def _parse_stream(self, jsonl_path: Path) -> dict[str, Any]:
        if not jsonl_path.exists():
            return {
                "stop_reason": None,
                "input_tokens": 0,
                "output_tokens": 0,
                "cost_usd": None,
            }
        return self._parse_lines(jsonl_path.read_text().splitlines())

    @abstractmethod
    def _parse_lines(self, lines: list[str]) -> dict[str, Any]: ...
