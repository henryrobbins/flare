import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, FormulationInput, Harness

from src.verify.base import (
    ReformulationResult,
    ReformulationRun,
    ReformulationVerifier,
)


class FLAREVerifierRun(ReformulationRun):
    """In-flight FLARE run, cancellable via a cooperative flag.

    FLARE's agent runs on either the Docker or Modal backend; both honor a
    cooperative ``should_cancel`` hook polled each tick. :meth:`cancel` flips a
    per-run flag that the in-flight :meth:`milp_flare.FLARE.verify` observes
    within one poll interval, stopping the agent, capturing partial artifacts,
    and tearing down its container/Sandbox. This unwinds gracefully on both
    backends — a force-kill would lose the Modal run's partial artifacts — so it
    is preferred over killing the container outright.

    The work runs synchronously inside :meth:`result`; :meth:`start` only
    captures the inputs. In the batch path, ``start()`` and ``result()`` are
    called back-to-back on the same worker thread, while the experiment runner
    holds the handle so it can :meth:`cancel` the run from another thread.
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
        self._cancel = threading.Event()

    def cancel(self) -> None:
        self._cancel.set()

    def result(self) -> ReformulationResult:
        # On the Docker backend the bind mount already makes
        # wd/agent_output.jsonl live locally, so we leave it alone. On a remote
        # backend (e.g. Modal) the file only lands at the end of the run, so we
        # mirror the agent's output snapshot into the local working directory
        # each tick — making `tail -f wd/agent_output.jsonl` live there too.
        on_output: Callable[[str], None] | None = None
        if self._inner.harness.runner.name != "docker":
            local_jsonl = self._output_path / "wd" / "agent_output.jsonl"

            def _mirror(text: str) -> None:
                local_jsonl.parent.mkdir(parents=True, exist_ok=True)
                local_jsonl.write_text(text)

            on_output = _mirror

        r = self._inner.verify(
            self._a_in,
            self._b_in,
            self._output_path,
            on_output=on_output,
            should_cancel=self._cancel.is_set,
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
