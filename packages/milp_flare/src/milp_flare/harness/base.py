from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any, ClassVar

from milp_flare.harness.cost import compute_cost_usd
from milp_flare.harness.runner import AuthSpec, DockerRunner, Runner


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
        """Return the credential-forwarding spec for this harness.

        The default forwards nothing. Subclasses override this to forward the
        env vars / host config dirs their agent CLI needs; the spec is
        compute-agnostic and applied by the configured :attr:`runner`.
        """
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

    def run(
        self,
        wd: Path,
        *,
        on_output: Callable[[str], None] | None = None,
        should_cancel: Callable[[], bool] | None = None,
        poll_interval: float = 2.0,
    ) -> HarnessRunResult:
        """Run the agent on the configured compute backend.

        Delegates execution to :attr:`runner` (Docker or Modal), then parses
        the agent's ``agent_output.jsonl`` (agent-specific) for tokens, cost,
        and stop reason. The runner is responsible for populating ``wd`` with
        ``agent_output.jsonl`` and the other entrypoint artifacts.

        Parameters
        ----------
        wd : pathlib.Path
            The agent working directory, already configured via
            :meth:`configure_wd`.
        on_output : Callable[[str], None], optional
            Live-output hook forwarded to :meth:`Runner.run`. Called each tick
            with the full current ``agent_output.jsonl`` snapshot. See
            :meth:`Runner.run` for the full-snapshot contract.
        should_cancel : Callable[[], bool], optional
            Cancellation hook forwarded to :meth:`Runner.run`. Polled each tick;
            returning ``True`` stops the agent and returns promptly.
        poll_interval : float, default ``2.0``
            Seconds between supervision ticks (only relevant with a hook).

        Returns
        -------
        result : HarnessRunResult
            Duration, cost, token counts, and stop reason.
        """

        # Print the path to the agent's JSONL output for easy monitoring in real time
        jsonl_path = wd / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        # Execute the agent on the compute backend (docker / modal).
        duration = self.runner.run(
            wd,
            self.auth_spec(),
            on_output=on_output,
            should_cancel=should_cancel,
            poll_interval=poll_interval,
        )

        parsed = self._parse_stream(jsonl_path)
        # Codex doesn't surface per-turn USD; fill from token totals.
        if parsed.get("cost_usd") is None:
            parsed["cost_usd"] = compute_cost_usd(
                self.model, parsed["input_tokens"], parsed["output_tokens"]
            )

        return HarnessRunResult(duration_s=round(duration, 1), **parsed)

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
