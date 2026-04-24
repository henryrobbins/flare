import json
import re
import subprocess
from pathlib import Path

from milp_eq_tools import Formulation
from milp_eq_tools.models import Constraint

from .checker import CheckResult, EquivalenceChecker
from .llm_client import LLMClient
from .prompts import problem_info, render_variable_mapping

TOLERANCE = 1e-6


def _compute_rhs(terms: list[dict], sol_b_vars: dict) -> float | list | dict | None:
    """Compute RHS value(s) by evaluating the linear combination against B's solution."""
    acc: dict = {}
    for term in terms:
        value = sol_b_vars.get(term["variable"])
        if value is None:
            return None
        c = term["constant"]
        if isinstance(value, list):
            for i, v in enumerate(value):
                if isinstance(v, list):
                    for j, vv in enumerate(v):
                        key = (i, j)
                        acc[key] = acc.get(key, 0.0) + c * float(vv)
                else:
                    acc[i] = acc.get(i, 0.0) + c * float(v)
        elif isinstance(value, dict):
            for k, v in value.items():
                acc[k] = acc.get(k, 0.0) + c * v
        else:
            acc[None] = acc.get(None, 0.0) + c * float(value)

    if None in acc and len(acc) == 1:
        return acc[None]
    if None not in acc:
        if all(isinstance(k, tuple) and len(k) == 2 for k in acc):
            max_i = max(k[0] for k in acc)
            max_j = max(k[1] for k in acc)
            return [[acc.get((i, j), 0.0) for j in range(max_j + 1)] for i in range(max_i + 1)]
        if all(isinstance(k, int) for k in acc):
            return [acc[k] for k in sorted(acc)]
        return acc
    return None


def _pinning_constraint(var_name: str, rhs: float | list | dict) -> Constraint:
    """Build a single Constraint that pins var_name to the given RHS value(s)."""
    if isinstance(rhs, (int, float)):
        code = f"model.addConstr({var_name} == {rhs!r})"
        formulation = f"{var_name} = {rhs}"
    elif isinstance(rhs, list) and rhs and isinstance(rhs[0], list):
        code = f"for _i, _row in enumerate({rhs!r}):\n    for _j, _v in enumerate(_row): model.addConstr({var_name}[_i, _j] == _v)"
        formulation = f"{var_name}[i,j] = rhs[i][j] for all i,j"
    elif isinstance(rhs, list):
        code = f"for _i, _v in enumerate({rhs!r}): model.addConstr({var_name}[_i] == _v)"
        formulation = f"{var_name}[i] = rhs[i] for all i"
    else:
        code = f"for _k, _v in {rhs!r}.items(): model.addConstr({var_name}[_k] == _v)"
        formulation = f"{var_name}[k] = rhs[k] for all k"

    return Constraint(
        description=f"Pin {var_name} to B's solution value",
        formulation=formulation,
        explicit=True,
        code={"gurobipy": code},
    )


def _parse_mapping(response: str, var_name: str, b_variables: dict) -> list[dict] | None:
    """Parse and validate LLM mapping response. Returns [] for no-mapping, None on parse failure."""
    match = re.search(r"\{.*\}", response, re.DOTALL)
    if not match:
        return None
    try:
        parsed = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None

    terms = parsed.get(var_name)
    if not isinstance(terms, list) or not terms:
        return None
    if terms[0].get("constant") == "none":
        return []

    valid: list[dict] = []
    for term in terms:
        constant = term.get("constant")
        variable = term.get("variable")
        if not isinstance(constant, (int, float)) or variable not in b_variables:
            return None
        valid.append({"constant": float(constant), "variable": variable})
    return valid


def _solve(formulation: Formulation, fdir: Path) -> dict:
    """gen_params → write solve.py → run → return solution dict."""
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
    return json.loads(solution_path.read_text())


class EquivaMapChecker(EquivalenceChecker):
    def __init__(self, runs_dir: Path, client: LLMClient) -> None:
        super().__init__(runs_dir)
        self.client = client

    @property
    def name(self) -> str:
        return "equivamap"

    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult:
        artifacts_dir = self.runs_dir / "pairs" / pair_id / "equivamap"
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        # Step 1: Solve B
        sol_b = _solve(b, artifacts_dir / "b")
        obj_b = float(sol_b["objective"])
        sol_b_vars = sol_b["variables"]

        # Step 2: Save problem_info artifacts
        info_a = problem_info(a)
        info_b = problem_info(b)
        (artifacts_dir / "problem_info_a.json").write_text(json.dumps(info_a, indent=2))
        (artifacts_dir / "problem_info_b.json").write_text(json.dumps(info_b, indent=2))

        # Step 3: LLM variable mapping discovery
        prompts_dir = artifacts_dir / "mapping_prompts"
        prompts_dir.mkdir(exist_ok=True)
        variable_mappings: dict[str, list[dict] | None] = {}

        for var_name in a.variables:
            rendered = render_variable_mapping(var_name, a, b)
            (prompts_dir / f"{var_name}_prompt.txt").write_text(rendered.user)
            response = self.client.complete(rendered.system, rendered.user)
            (prompts_dir / f"{var_name}_response.txt").write_text(response)
            variable_mappings[var_name] = _parse_mapping(response, var_name, info_b["variables"])

        (artifacts_dir / "variable_mappings.json").write_text(
            json.dumps(variable_mappings, indent=2)
        )

        # Step 4: Compute pinning constraints and build modified formulation A
        map_lines: list[str] = []
        pinned_a = a

        for var_name, terms in variable_mappings.items():
            if not terms:
                continue
            rhs = _compute_rhs(terms, sol_b_vars)
            if rhs is None:
                continue
            constraint = _pinning_constraint(var_name, rhs)
            pinned_a = pinned_a.with_constraint(constraint)
            map_lines.append(constraint.code["gurobipy"])

        (artifacts_dir / "map_constraints.py").write_text("\n".join(map_lines))

        # Step 5: Solve A with pinning constraints
        sol_a = _solve(pinned_a, artifacts_dir / "a_constrained")
        obj_a_constrained = float(sol_a["objective"])

        # Step 6: Compare objectives
        is_equiv = abs(obj_b - obj_a_constrained) < TOLERANCE
        meta = {
            "is_equivalent": is_equiv,
            "obj_b": obj_b,
            "obj_a_constrained": obj_a_constrained,
        }
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return CheckResult(
            is_equivalent=is_equiv,
            method=self.name,
            artifacts_dir=artifacts_dir,
            metadata=meta,
        )
