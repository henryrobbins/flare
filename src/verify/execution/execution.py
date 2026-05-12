import json
import subprocess
import time
from pathlib import Path
from typing import Any

from formulation_bench import Formulation

from src.verify.base import ReformulationResult, ReformulationVerifier

TOLERANCE = 1e-6


class ExecutionVerifier(ReformulationVerifier):
    @property
    def name(self) -> str:
        return "execution"

    def method_config(self) -> dict[str, Any]:
        return {"tolerance": TOLERANCE}

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        start = time.time()
        obj_a = self._solve(a, artifacts_dir / "a")
        obj_b = self._solve(b, artifacts_dir / "b")
        duration_s = round(time.time() - start, 1)

        is_reform = abs(obj_a - obj_b) < TOLERANCE
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
        formulation.gen_params(output_path=params_path)

        solve_path = fdir / "solve.py"
        solve_path.write_text(formulation.gurobipy_code)

        solution_path = fdir / "solution.json"
        subprocess.run(
            ["python", str(solve_path), str(params_path), str(solution_path)],
            check=True,
            capture_output=True,
        )

        return float(json.loads(solution_path.read_text())["objective"])
