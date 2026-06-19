from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

from milp_flare.harness.cost import compute_cost_usd
from milp_flare.harness.runner import AgentRun, AuthSpec, DockerRunner, Runner


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


class Harness(ABC):
    """Base class for FLARE agent harness.

    :class:`FLARE` uses an agent harness to auto-formalize MILP formulations in
    Lean and do automated formal proof synthesis (AFPS) of reformulation
    certificates. A harness owns the *agent* concern (which CLI to launch, how
    to authenticate it, how to parse its output) and delegates the *compute*
    concern (where the container runs) to an injected
    :class:`~milp_flare.harness.runner.Runner`.

    Parameters
    ----------
    model : str
        Model identifier (e.g., ``"claude-opus-4-7"``, ``"gpt-5.5"``). See
        harness subclasses for supported models.
    effort : str, default ``"medium"``
        Reasoning effort level (``"low"``, ``"medium"``, ``"high"``). See
        harness subclasses for supported effort levels.
    runner : Runner, optional
        The compute backend to execute the agent container. Defaults to
        :class:`~milp_flare.harness.runner.DockerRunner` (local Docker).

    Attributes
    ----------
    name : str
        Name of the agent harness (e.g., ``"claude_code"``).
    model : str
        Model identifier this harness is configured to use.
    effort : str
        Reasoning effort level this harness is configured to use.
    runner : Runner
        The compute backend this harness runs on.
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

    def auth_spec(self) -> AuthSpec:
        """Return the credential-forwarding spec for this harness."""
        return AuthSpec(env=[], home_dirs=[])

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

    def start(self, wd: Path) -> AgentRun:
        """Provision the compute and start the agent, returning a live handle.

        Provision the compute, populate the agent working directory in the
        container, and configure necessary agent credentials. Then, launch the
        agent and return a live handle to the in-flight run.

        The caller is responsible for draining the :meth:`AgentRun.stdout` stream,
        otherwise the agent may block on a full stdout buffer. Additionally, the
        caller should :meth:`~AgentRun.close` the run once done to release the
        compute and capture any partial output. It is recommended to use
        :meth:`collect` which handles both of these responsibilities.

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory on the host.
        """
        # Print the path to the agent's JSONL output for easy monitoring in real time
        print(f"  [flare] monitor: tail -f {wd / 'agent_output.jsonl'}")
        return self.runner.start(wd, self.auth_spec())

    def collect(self, agent: AgentRun, wd: Path) -> HarnessRunResult:
        """Collect agent output until completion, then parse it and return the result.

        Agent output is written to ``agent_output.jsonl`` in the working directory
        as a stream of JSON lines. When the agent process exits, the agent run is
        closed, and the final results are parsed and returned.

        Returns
        -------
        result : HarnessRunResult
            Duration, cost, token counts, and stop reason.
        """
        jsonl_path = wd / "agent_output.jsonl"
        # The host rebuilds agent_output.jsonl live from the streamed stdout
        # lines, so the file exists and grows the same way on every backend.
        try:
            with jsonl_path.open("w") as f:
                for line in agent.stdout:
                    f.write(line)
                    f.write("\n")
                    f.flush()
        finally:
            agent.close()

        parsed = self._parse_stream(jsonl_path)
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self.model, parsed["input_tokens"], parsed["output_tokens"]
            )

        return HarnessRunResult(duration_s=round(agent.duration_s, 1), **parsed)

    def run(self, wd: Path) -> HarnessRunResult:
        """Start the agent and collect the results.

        If the called needs direct access to the live AgentRun handle in order
        to cancel the run from another thread, it can call :meth:`start` and
        :meth:`collect` separately.
        """
        return self.collect(self.start(wd), wd)

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
