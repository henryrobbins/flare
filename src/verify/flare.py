import threading
from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, AgentRun, FormulationInput, Harness

from src.verify.base import (
    ReformulationResult,
    ReformulationRun,
    ReformulationVerifier,
)


class FLAREVerifierRun(ReformulationRun):
    """In-flight FLARE run, cancellable from another thread.

    FLARE's agent runs on either the Docker or Modal backend. :meth:`cancel`
    stops the live :class:`~milp_flare.AgentRun` directly (``docker kill`` /
    ``pkill`` inside the Sandbox); the in-flight :meth:`milp_flare.FLARE.verify`
    then unwinds, capturing whatever partial artifacts exist before tearing down
    its container/Sandbox. The same cooperative path is used on both backends, so
    a canceled run keeps its partial output everywhere.

    The work runs synchronously inside :meth:`result`; :meth:`start` only
    captures the inputs. In the batch path, ``start()`` and ``result()`` are
    called back-to-back on the same worker thread, while the experiment runner
    holds the handle so it can :meth:`cancel` the run from another thread. A
    cancel that arrives before the agent has started is recorded and applied the
    instant the handle is published via :meth:`_on_start`.
    """

    def __init__(
        self,
        inner: FLARE,
        a_in: FormulationInput,
        b_in: FormulationInput,
        output_path: Path,
        name: str,
    ) -> None:
        self._inner = inner
        self._a_in = a_in
        self._b_in = b_in
        self._output_path = output_path
        self._name = name
        self._lock = threading.Lock()
        self._agent: AgentRun | None = None
        self._canceled = False

    def cancel(self) -> None:
        with self._lock:
            self._canceled = True
            if self._agent is not None:
                self._agent.cancel()

    def _on_start(self, agent: AgentRun) -> None:
        # Publish the live handle so cancel() can reach it; if a cancel already
        # arrived during setup, apply it now (kills the agent just after it
        # started, capturing whatever partial artifacts exist on teardown).
        with self._lock:
            self._agent = agent
            if self._canceled:
                agent.cancel()

    def result(self) -> ReformulationResult:
        r = self._inner.verify(
            self._a_in,
            self._b_in,
            self._output_path,
            on_start=self._on_start,
        )
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=self._name,
            artifacts_dir=self._output_path,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )


class FLAREVerifier(ReformulationVerifier):
    """Adapts `milp_flare.FLARE` to `ReformulationVerifier` API."""

    def __init__(self, harness: Harness) -> None:
        self._inner = FLARE(harness=harness)

    @property
    def name(self) -> str:
        return "flare"

    def get_config_dict(self) -> dict[str, Any]:
        return self._inner.get_config_dict()

    def start(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> FLAREVerifierRun:
        a_in = FormulationInput(
            formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
        )
        b_in = FormulationInput(
            formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
        )
        return FLAREVerifierRun(self._inner, a_in, b_in, output_path, self.name)
