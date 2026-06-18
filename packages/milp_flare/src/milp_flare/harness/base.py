from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

from milp_flare.harness.cost import compute_cost_usd
from milp_flare.harness.runner import AuthSpec, DockerRunner, Runner, RunnerRun


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
    """Handle for a single in-flight agent run.

    Wraps the compute-level :class:`~milp_flare.harness.runner.base.RunnerRun`
    returned by the harness's runner, forwarding cancellation and waiting on it
    before parsing the agent output. The agent concern (parsing, cost) lives
    here; the compute concern (launch, kill, timing) lives in the runner.
    """

    def __init__(
        self,
        harness: "Harness",
        runner_run: RunnerRun,
        wd: Path,
    ) -> None:
        self._harness = harness
        self._runner_run = runner_run
        self._wd = wd

    def cancel(self) -> None:
        """Stop the run by cancelling the underlying compute; idempotent."""
        self._runner_run.cancel()

    def result(self) -> HarnessRunResult:
        """Block until the agent exits, then parse and return its result."""
        duration = self._runner_run.wait()

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
    runner : Runner, optional
        Compute backend used to launch the agent container. Defaults to
        :class:`~milp_flare.harness.runner.docker.DockerRunner`.

    Attributes
    ----------
    name : str
        Name of the agent harness (e.g., ``"claude_code"``).
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.
    runner : Runner
        Compute backend used to launch the agent container.
    """

    name: ClassVar[str]

    def __init__(
        self, model: str, effort: str = "medium", runner: Runner | None = None
    ) -> None:
        self.model = model
        self.effort = effort
        self.runner = runner or DockerRunner()

    def get_config_dict(self) -> dict[str, Any]:
        """Return a dictionary with the harness configuration.

        Returns
        -------
        config : dict[str, Any]
            Harness name, compute backend, image, model, and effort.
        """
        return {
            "harness": self.name,
            "compute": self.runner.name,
            "image": self.runner.image,
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
        """Launch the agent on the configured compute backend and return a handle.

        Delegates the compute concern to :attr:`runner` (which launches the
        container, bind-mounts ``wd``, and forwards credentials per
        :meth:`auth_spec`). The container entrypoint calls the agent command
        script which launches the agent. Agent output is written to
        ``wd/agent_output.jsonl``.

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory the runner launches against.

        Returns
        -------
        run : HarnessRun
            Handle to the in-flight run.
        """
        # Print the path to the agent's JSONL output for easy monitoring in real time
        jsonl_path = wd / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        runner_run = self.runner.start(wd, self.auth_spec())
        return HarnessRun(harness=self, runner_run=runner_run, wd=wd)

    def run(self, wd: Path) -> HarnessRunResult:
        """Run the agent on the compute backend and block for the result.

        Convenience wrapper over :meth:`start`: launches the run and waits for
        it to finish. Equivalent to ``self.start(wd).result()``.
        """
        return self.start(wd).result()

    @abstractmethod
    def auth_spec(self) -> AuthSpec:
        """Return the credential-forwarding spec for this harness.

        The default forwards nothing. Subclasses override this to forward the
        env vars / host config dirs their agent CLI needs; the spec is
        compute-agnostic and applied by the configured :attr:`runner`.
        """
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
