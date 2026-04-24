#!/usr/bin/env python3
"""Generate solve.py files from formulation.json."""

import argparse
import json
import re
import subprocess
import tempfile

from milp_eq_tools import Dataset

TYPE_MAP = {
    "continuous": "CONTINUOUS",
    "integer": "INTEGER",
    "binary": "BINARY",
}

def _gurobi_type(var: dict[str, object]) -> str:
    raw_type = str(var.get("type", "continuous"))
    return f"GRB.{TYPE_MAP.get(raw_type, 'CONTINUOUS')}"


def _detect_imports(codes: list[str]) -> tuple[bool, bool]:
    """Return (use_gp_prefix, needs_bare_quicksum)."""
    joined = "\n".join(codes)
    use_gp = "gp." in joined
    bare_quicksum = bool(re.search(r"(?<![.\w])quicksum", joined))
    return use_gp, bare_quicksum


def _var_decl(name: str, var: dict[str, object]) -> str:
    vtype = _gurobi_type(var)
    indices = var.get("indices")
    if indices is not None:
        return f'{name} = model.addVars([{indices}], vtype={vtype}, name="{name}")'
    shape = list(var.get("shape", []))  # type: ignore[arg-type]
    if not shape:
        return f'{name} = model.addVar(vtype={vtype}, name="{name}")'
    dims = ", ".join(str(d) for d in shape)
    return f'{name} = model.addVars({dims}, vtype={vtype}, name="{name}")'


def _solution_extraction(name: str, var: dict[str, object]) -> list[str]:
    if var.get("indices") is not None:
        return [f'variables["{name}"] = {{str(list(k)): {name}[k].x for k in {name}}}']
    shape = list(var.get("shape", []))  # type: ignore[arg-type]
    if not shape:
        return [f'variables["{name}"] = {name}.x']
    if len(shape) == 1:
        d = shape[0]
        return [f'variables["{name}"] = [{name}[i].x for i in range({d})]']
    if len(shape) == 2:
        d1, d2 = shape
        return [
            f'variables["{name}"] = '
            f'[[{name}[i, j].x for j in range({d2})] for i in range({d1})]'
        ]
    # Higher-dimensional: nested list comprehension
    iters = ["i", "j", "k", "l"][: len(shape)]
    idx = ", ".join(iters)
    result: str = f"{name}[{idx}].x"
    for iter_var, dim in reversed(list(zip(iters, shape))):
        result = f"[{result} for {iter_var} in range({dim})]"
    return [f'variables["{name}"] = {result}']


def generate(formulation_json: dict[str, object]) -> str:
    params = dict(formulation_json.get("parameters", {}))  # type: ignore[arg-type]
    assumptions = list(formulation_json.get("assumptions", []))  # type: ignore[arg-type]
    definitions = dict(formulation_json.get("definitions", {}))  # type: ignore[arg-type]
    variables = dict(formulation_json.get("variables", {}))  # type: ignore[arg-type]
    constraints = list(formulation_json.get("constraints", []))  # type: ignore[arg-type]
    objective = dict(formulation_json.get("objective", {}))  # type: ignore[arg-type]

    explicit_constraints = [c for c in constraints if c.get("explicit", True)]  # type: ignore[union-attr]
    implicit_constraints = [c for c in constraints if not c.get("explicit", True)]  # type: ignore[union-attr]

    all_codes = [
        str(c.get("code", {}).get("gurobipy", "")) for c in constraints  # type: ignore[union-attr]
    ] + [str(objective.get("code", {}).get("gurobipy", ""))]  # type: ignore[union-attr]
    use_gp, bare_quicksum = _detect_imports(all_codes)

    L: list[str] = []

    # Imports
    L.append("import json")
    if use_gp:
        L.append("import gurobipy as gp")
        gurobi_imports = "GRB, quicksum" if bare_quicksum else "GRB"
        L.append(f"from gurobipy import {gurobi_imports}")
    else:
        gurobi_imports = "Model, GRB, quicksum" if bare_quicksum else "Model, GRB"
        L.append(f"from gurobipy import {gurobi_imports}")
    L.append("import argparse")
    L.append("")
    L.append("")

    # Function
    L.append("def main(params_path: str, solution_path: str) -> None:")
    L.append("")
    L.append("    # Create a new model")
    L.append("    model = gp.Model()" if use_gp else "    model = Model()")
    L.append("")
    L.append("    # Load data")
    L.append('    with open(params_path, "r") as f:')
    L.append("        data = json.load(f)")
    L.append("")

    # Parameters
    if params:
        L.append("    # Parameters")
        for name, p in params.items():
            L.append(f'    {name} = data["{name}"]')
        L.append("")

    # Parameter Validation
    if assumptions:
        L.append("    # Parameter Validation")
        for a in assumptions:
            a = dict(a)  # type: ignore[arg-type]
            code = str(a.get("code", {}).get("python", "")).strip()  # type: ignore[union-attr]
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Definitions
    if definitions:
        L.append("    # Definitions")
        for name, d in definitions.items():
            d = dict(d)  # type: ignore[arg-type]
            code = str(d.get("code", {}).get("python", "")).strip()  # type: ignore[union-attr]
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Variables
    if variables:
        L.append("    # Variables")
        for name, v in variables.items():
            v = dict(v)  # type: ignore[arg-type]
            L.append(f"    {_var_decl(name, v)}")
        L.append("")

    # Constraints
    L.append("    # Constraints")
    for c in explicit_constraints:
        c = dict(c)  # type: ignore[arg-type]
        code = str(c.get("code", {}).get("gurobipy", "")).strip()  # type: ignore[union-attr]
        if code:
            for line in code.split("\n"):
                L.append(f"    {line}")
    L.append("")

    # Implicit Constraints
    if implicit_constraints:
        L.append("    # Implicit Constraints")
        for c in implicit_constraints:
            c = dict(c)  # type: ignore[arg-type]
            code = str(c.get("code", {}).get("gurobipy", "")).strip()  # type: ignore[union-attr]
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Objective
    obj_code = str(objective.get("code", {}).get("gurobipy", "")).strip()  # type: ignore[union-attr]
    L.append("    # Objective")
    if obj_code:
        for line in obj_code.split("\n"):
            L.append(f"    {line}")
    L.append("")

    # Solve
    L.append("    # Solve")
    L.append("    model.optimize()")
    L.append("")

    # Extract solution
    L.append("    # Extract solution")
    L.append("    solution = {}")
    L.append("    variables = {}")
    for name, v in variables.items():
        v = dict(v)  # type: ignore[arg-type]
        for line in _solution_extraction(name, v):
            L.append(f"    {line}")
    L.append('    solution["variables"] = variables')
    L.append('    solution["objective"] = model.objVal')
    L.append('    with open(solution_path, "w") as f:')
    L.append('        json.dump(solution, f, indent=4)')
    L.append("")
    L.append("")

    # Entry point
    L.append('if __name__ == "__main__":')
    L.append("    parser = argparse.ArgumentParser()")
    L.append('    parser.add_argument("params", help="Path to parameters.json")')
    L.append('    parser.add_argument("solution", help="Path to write solution.json")')
    L.append("    args = parser.parse_args()")
    L.append("    main(args.params, args.solution)")
    L.append("")

    return _ruff_format("\n".join(L))


def _ruff_format(code: str) -> str:
    with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False) as f:
        f.write(code)
        tmp = f.name
    subprocess.run(["ruff", "format", "--quiet", tmp], check=True)
    with open(tmp) as f:
        return f.read()


def parse_problem_ids(s: str | None) -> set[int] | None:
    if s is None:
        return None
    return {int(x.strip()) for x in s.split(",")}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "dataset",
        nargs="?",
        default="dataset",
        help="path to the dataset root (default: ./dataset)",
    )
    parser.add_argument(
        "--problems",
        "-p",
        help="comma-separated list of problem numbers (e.g. 1,2,3)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print generated code without writing files",
    )
    args = parser.parse_args()

    dataset = Dataset(args.dataset)
    problem_filter = parse_problem_ids(args.problems)

    for pid, problem in dataset.problems.items():
        if problem_filter is not None and pid not in problem_filter:
            continue
        for fid, formulation in problem.formulations.items():
            fj_path = formulation.path / "formulation.json"
            fj = json.loads(fj_path.read_text())
            code = generate(fj)

            if args.dry_run:
                print(f"=== p{pid}/{fid}/solve.py ===")
                print(code)
            else:
                out = formulation.path / "solve.py"
                out.write_text(code)
                print(f"generated p{pid}/{fid}/solve.py")


if __name__ == "__main__":
    main()
