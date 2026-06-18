import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

from formulation_bench import Formulation
from milp_flare import FLARE, FormulationInput, Harness

from src.verify.base import ReformulationResult, ReformulationVerifier

#: Process-wide cooperative cancel flag for FLARE runs. The experiment runner
#: sets this on Ctrl+C (see ``experiments/utils.py``); every in-flight
#: :meth:`FLAREVerifier.verify` polls it via the ``should_cancel`` hook and
#: stops its agent within one ``poll_interval``, so a batch interrupt unwinds
#: gracefully on both the Docker and Modal backends (no force-kill needed).
CANCEL_EVENT = threading.Event()


class FLAREVerifier(ReformulationVerifier):
    """Adapter exposing the milp_flare verifier as a ReformulationVerifier."""

    def __init__(self, harness: Harness) -> None:
        self._inner = FLARE(harness=harness)

    @property
    def name(self) -> str:
        return "flare"

    def get_config_dict(self) -> dict[str, Any]:
        return self._inner.get_config_dict()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        a_in = FormulationInput(
            formulation_md=a.render_markdown(), solve_py=a.gen_solve_py()
        )
        b_in = FormulationInput(
            formulation_md=b.render_markdown(), solve_py=b.gen_solve_py()
        )

        # On the Docker backend the bind mount already makes
        # wd/agent_output.jsonl live locally, so we leave it alone. On a remote
        # backend (e.g. Modal) the file only lands at the end of the run, so we
        # mirror the agent's output snapshot into the local working directory
        # each tick — making `tail -f wd/agent_output.jsonl` live there too.
        on_output: Callable[[str], None] | None = None
        if self._inner.harness.runner.name != "docker":
            local_jsonl = output_path / "wd" / "agent_output.jsonl"

            def _mirror(text: str) -> None:
                local_jsonl.parent.mkdir(parents=True, exist_ok=True)
                local_jsonl.write_text(text)

            on_output = _mirror

        r = self._inner.verify(
            a_in,
            b_in,
            output_path,
            on_output=on_output,
            should_cancel=CANCEL_EVENT.is_set,
        )
        return ReformulationResult(
            is_reformulation=r.is_reformulation,
            method=self.name,
            artifacts_dir=output_path,
            duration_s=r.duration_s,
            cost_usd=r.cost_usd,
            metadata=r.metadata,
        )
