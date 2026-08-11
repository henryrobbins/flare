import json
import math
import subprocess
import time
from pathlib import Path
from typing import Any

from formulation_bench import Formulation, Reformulation

from src.verify.base import ReformulationResult, SynchronousVerifier

REL_TOLERANCE = 1e-6


class ExecutionVerifier(SynchronousVerifier):
    @property
    def name(self) -> str:
        return "execution"

    def get_config_dict(self) -> dict[str, Any]:
        return {"rel_tolerance": REL_TOLERANCE}

    def _verify(self, pair: Reformulation, output_path: Path) -> ReformulationResult:
        # This method compares fixed instances, so the pair's parameter map is ignored.
        a, b = pair.a, pair.b
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.get_config_dict(), indent=2)
        )

        start = time.time()
        obj_a = self._solve(a, artifacts_dir / "a")
        obj_b = self._solve(b, artifacts_dir / "b")
        duration_s = round(time.time() - start, 1)

        is_reform = math.isclose(obj_a, obj_b, rel_tol=REL_TOLERANCE, abs_tol=0.0)
        meta = {"is_reformulation": is_reform, "obj_a": obj_a, "obj_b": obj_b}
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return ReformulationResult(
            is_reformulation=is_reform,
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=duration_s,
            cost_usd=None,
            metadata=meta,
        )

    def _solve(self, formulation: Formulation, fdir: Path) -> float:
        fdir.mkdir(parents=True, exist_ok=True)

        params_path = fdir / "parameters.json"
        formulation.run_gen_params(output_path=params_path)

        solve_path = fdir / "solve.py"
        solve_path.write_text(formulation.gen_solve_py())

        solution_path = fdir / "solution.json"
        subprocess.run(
            ["python", str(solve_path), str(params_path), str(solution_path)],
            check=True,
            capture_output=True,
        )

        return float(json.loads(solution_path.read_text())["objective"])
