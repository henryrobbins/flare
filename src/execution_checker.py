import json
import subprocess
from pathlib import Path

from milp_eq_tools import Formulation

from .checker import CheckResult, EquivalenceChecker

TOLERANCE = 1e-6


class ExecutionChecker(EquivalenceChecker):
    @property
    def name(self) -> str:
        return "execution"

    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult:
        artifacts_dir = self.runs_dir / "pairs" / pair_id / "execution"
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        obj_a = self._solve(a, artifacts_dir / "a")
        obj_b = self._solve(b, artifacts_dir / "b")

        is_equiv = abs(obj_a - obj_b) < TOLERANCE
        meta = {"is_equivalent": is_equiv, "obj_a": obj_a, "obj_b": obj_b}
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return CheckResult(
            is_equivalent=is_equiv,
            method=self.name,
            artifacts_dir=artifacts_dir,
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
