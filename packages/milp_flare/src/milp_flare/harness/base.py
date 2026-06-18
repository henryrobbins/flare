import os
import subprocess
import time
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import IO, Any, ClassVar

from milp_flare.harness.cost import compute_cost_usd

#: The name of the Docker image containing the agent environment. This image is
#: expected to be built prior to running FLARE. See :doc:`/installation`.
IMAGE = "flare-agent:latest"


@dataclass
class HarnessRunResult:
    """Result of a harness run returned by :meth:`Harness.run`.

    Attributes
    ----------
    duration_s : float
        Wall-clock duration of the agent run, in seconds.
    cost_usd : float, optional
        Estimated USD cost of the agent run, or ``None`` if cost information
        is not available (e.g., model is missing from :const:`COST_PER_MTOK`).
    input_tokens : int
        Total input (prompt) tokens reported by the agent stream. Used by
        :const:`COST_PER_MTOK` to estimate ``cost_usd`` when not directly
        reported by the agent.
    output_tokens : int
        Total output (completion) tokens reported by the agent stream. Used by
        :const:`COST_PER_MTOK` to estimate ``cost_usd`` when not directly
        reported by the agent.
    stop_reason : str, optional
        Final stop reason reported by the agent (e.g., ``"end_turn"``,
        ``"max_tokens"``). ``None`` if not reported.
    """

    duration_s: float
    cost_usd: float | None
    input_tokens: int
    output_tokens: int
    stop_reason: str | None


class HarnessRun:
    """Handle for a single in-flight Docker agent run.

    Returned by :meth:`Harness.start`. Owns exactly one Docker container (named
    uniquely so it can be addressed on its own), giving a 1-1 handle on the run:
    :meth:`cancel` ``docker kill``\\ s that one container, and :meth:`result`
    blocks until the container exits and parses its output into a
    :class:`HarnessRunResult`. ``cancel`` is safe to call from another thread
    while ``result`` is blocking — the kill makes the container exit, which lets
    the awaited process return — and is idempotent.
    """

    def __init__(
        self,
        harness: "Harness",
        proc: "subprocess.Popen[bytes]",
        container: str,
        wd: Path,
        stderr_file: IO[bytes],
        start_time: float,
    ) -> None:
        self._harness = harness
        self._proc = proc
        self._container = container
        self._wd = wd
        self._stderr_file = stderr_file
        self._start_time = start_time

    def cancel(self) -> None:
        """Stop the run by killing its container; idempotent and thread-safe.

        ``docker kill`` by the container's unique name (not the Popen client);
        safe to re-issue and a no-op if the container has already exited.
        """
        subprocess.run(
            ["docker", "kill", self._container],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def result(self) -> HarnessRunResult:
        """Block until the container exits, then parse and return its result."""
        self._proc.wait()
        self._stderr_file.close()
        duration = time.time() - self._start_time

        stderr_path = self._wd / f"{self._harness.name}_stderr.txt"
        # Drop an empty stderr file so artifacts match the historical behavior
        # (which only wrote it when the container produced stderr).
        if stderr_path.exists() and stderr_path.stat().st_size == 0:
            stderr_path.unlink()

        parsed = self._harness._parse_stream(self._wd / "agent_output.jsonl")
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self._harness.model, parsed["input_tokens"], parsed["output_tokens"]
            )
        return HarnessRunResult(duration_s=round(duration, 1), **parsed)


class Harness(ABC):
    """Base class for FLARE agent harness.

    :class:`FLARE` uses an agent harness to auto-formalize MILP formulations in
    Lean and do automated formal proof synthesis (AFPS) of reformulation
    certificates. This is the base class for a :class:`FLARE` agent
    harness. It has methods to configure the agent working directory, run the
    agent in a Docker container, and return a configuration dictionary.

    Parameters
    ----------
    model : str
        Model identifier (e.g., ``"claude-opus-4-7"``, ``"gpt-5.5"``). See
        harness subclasses for supported models.
    effort : str, default ``"medium"``
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``). See
        harness subclasses for supported effort levels.

    Attributes
    ----------
    name : str
        Name of the agent harness (e.g., ``"claude_code"``).
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.
    """

    name: ClassVar[str]

    def __init__(self, model: str, effort: str = "medium") -> None:
        self.model = model
        self.effort = effort

    def get_config_dict(self) -> dict[str, Any]:
        """Return a dictionary with the harness configuration.

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
        """Configure the agent working directory with necessary files for the harness.

        The agent working directory needs the following:

        1. An agent command script (``agent.sh``) that is called by the Docker
           container entrypoint to launch the agent. The script typically calls
           an agent CLI in non-interactive mode.
        2. Any configuration files necessary to enable the
           `lean-lsp-mcp <https://github.com/oOo0oOo/lean-lsp-mcp>`_ MCP server.
        3. Custom Agent Skills for auto-formalization of MILP formulations and
           automated formal proof synthesis for reformulation (see :doc:`/skills`).

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory (on the host). Must already exist.

        Raises
        ------
        RuntimeError
            If ``wd`` does not exist.
        """

        if not wd.exists():
            raise RuntimeError("The agent working directory hasn't been created yet.")

        # Add the agent command script to be called by the container entrypoint
        # See milp_flare/assets/docker/entrypoint.sh
        (wd / "agent.sh").write_text(self._agent_command())

    def start(self, wd: Path) -> HarnessRun:
        """Launch the agent in a Docker container and return a run handle.

        Spawns a Docker container with the image specified by :const:`IMAGE` and
        bind-mounts ``wd`` into the container. The container entrypoint calls the
        agent command script which launches the agent. Agent output is written to
        ``wd/agent_output.jsonl`` (visible live through the bind mount). Returns
        immediately with a :class:`HarnessRun`; call :meth:`HarnessRun.result` to
        block for the verdict or :meth:`HarnessRun.cancel` to stop the run.

        The container gets a unique ``--name`` so a single run can be cancelled
        (``docker kill <name>``) independently of any others in the batch. stdout
        and stderr are redirected to ``/dev/null`` and a file so the undrained
        pipes can't deadlock while the run is in flight.

        The Docker image is expected to be built (see :doc:`/installation`).

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory to bind-mount at
            ``/workspace/wd`` in the container.

        Returns
        -------
        run : HarnessRun
            Handle to the in-flight run (cancel / await its result).
        """
        # Print the path to the agent's JSONL output for easy monitoring in real time
        jsonl_path = wd / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        container = f"flare-{uuid.uuid4().hex[:12]}"
        stderr_file = open(wd / f"{self.name}_stderr.txt", "wb")
        start = time.time()
        proc = subprocess.Popen(
            self._build_docker_cmd(wd, name=container),
            stdout=subprocess.DEVNULL,
            stderr=stderr_file,
            # Without start_new_session, Ctrl+C in the terminal sends SIGINT to both
            # the driver and the agent container, which can cause the container to
            # terminate prematurely. start_new_session=True detaches the subprocess
            # from the terminal's process group.
            start_new_session=True,
        )
        return HarnessRun(self, proc, container, wd, stderr_file, start)

    def run(self, wd: Path) -> HarnessRunResult:
        """Run the agent in a Docker container and block for the result.

        Convenience wrapper over :meth:`start`: launches the run and waits for
        it to finish. Equivalent to ``self.start(wd).result()``.
        """
        return self.start(wd).result()

    def _build_docker_cmd(self, wd: Path, name: str | None = None) -> list[str]:
        """Assemble the full ``docker run`` command for this harness."""
        cmd = ["docker", "run"]
        # Automatically remove the container when it exits
        cmd += ["--rm"]
        # A unique per-run name enables per-run cancel (`docker kill <name>`)
        # without affecting other containers in the same batch.
        if name:
            cmd += ["--name", name]
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
