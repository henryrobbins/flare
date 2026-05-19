import os
import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

from milp_flare.harness.cost import compute_cost_usd


@dataclass
class HarnessRunResult:
    """Per-run result returned by :meth:`Harness.run`.

    Attributes
    ----------
    duration_s : float
        Wall-clock duration of the agent run, in seconds.
    cost_usd : float, optional
        Estimated USD cost of the agent run, or ``None`` if the model is
        unpriced and the harness cannot report cost directly.
    input_tokens : int
        Total input (prompt) tokens reported by the agent stream.
    output_tokens : int
        Total output (completion) tokens reported by the agent stream.
    stop_reason : str, optional
        Final stop reason reported by the agent (e.g., ``"end_turn"``,
        ``"max_tokens"``). ``None`` if not reported.
    """

    duration_s: float
    cost_usd: float | None
    input_tokens: int
    output_tokens: int
    stop_reason: str | None


IMAGE = "flare-agent:latest"


class Harness(ABC):
    """Base class for FLARE agent harnesses.

    A harness drives a specific coding-agent CLI (Claude Code, Codex,
    OpenCode) inside the ``flare-agent`` Docker container. Concrete
    subclasses provide harness-specific Docker arguments, the agent
    launch command, and a parser for the agent's JSONL output stream.

    Parameters
    ----------
    model : str
        Model identifier passed to the underlying CLI (e.g.,
        ``"claude-opus-4-7"``, ``"gpt-5.4"``).
    effort : str, default ``"medium"``
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``).
        Forwarded to the harness-specific configuration.

    Attributes
    ----------
    name : str
        Class-level harness name (e.g., ``"claude_code"``).
    model : str
        The model identifier this harness was constructed with.
    effort : str
        The reasoning effort level this harness was constructed with.
    """

    name: ClassVar[str]

    def __init__(self, model: str, effort: str = "medium") -> None:
        self.model = model
        self.effort = effort

    def get_config_dict(self) -> dict[str, Any]:
        """Return the config dict written to ``<output_path>/config.json``.

        Returns
        -------
        config : dict[str, Any]
            Harness name, Docker image, model, and effort.
        """
        return {
            "harness": self.name,
            "image": IMAGE,
            "model": self.model,
            "effort": self.effort,
        }

    def configure_wd(self, wd: Path) -> None:
        """Write harness-specific files to the agent working directory.

        Subclasses extend this to drop in MCP configuration, skill
        bundles, and any other per-harness assets. The base
        implementation writes the agent launch script (``agent.sh``) used
        by the container entrypoint.

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory. Must already exist.
        """

        if not wd.exists():
            raise RuntimeError("The agent working directory hasn't been created yet.")

        # Add the agent command script to be called by the container entrypoint
        # See milp_flare/assets/docker/entrypoint.sh
        (wd / "agent.sh").write_text(self._agent_command())

    def run(self, wd: Path) -> HarnessRunResult:
        """Run the agent in a Docker container against ``wd``.

        Spawns ``docker run`` with the image-baked Lean environment,
        bind-mounts ``wd`` into the container, and waits for the agent to
        exit. Parses ``wd/agent_output.jsonl`` for token and cost
        metadata.

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory to bind-mount at
            ``/workspace/wd`` in the container.

        Returns
        -------
        result : HarnessRunResult
            Duration, cost, token counts, and stop reason.
        """

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
        """Assemble the full ``docker run`` command for this harness."""
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
        """Agent-specific ``docker run`` args (env vars, additional mounts, etc.)."""
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
