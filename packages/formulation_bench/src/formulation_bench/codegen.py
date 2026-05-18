"""Generate ``gurobipy`` solver code from a ``formulation.json`` dict.

This module is the deterministic codegen used to produce each formulation's
``solve.py`` from its JSON description. The single public entry point is
:func:`generate`; everything else is an internal helper.
"""

import re
from typing import Any

TYPE_MAP = {
    "continuous": "CONTINUOUS",
    "integer": "INTEGER",
    "binary": "BINARY",
}


def _gurobi_type(var: dict[str, Any]) -> str:
    raw_type = str(var.get("type", "continuous"))
    return f"GRB.{TYPE_MAP.get(raw_type, 'CONTINUOUS')}"


def _detect_imports(codes: list[str]) -> tuple[bool, bool]:
    """Return (use_gp_prefix, needs_bare_quicksum)."""
    joined = "\n".join(codes)
    use_gp = "gp." in joined
    bare_quicksum = bool(re.search(r"(?<![.\w])quicksum", joined))
    return use_gp, bare_quicksum


def _has_ragged(shape: list[Any]) -> bool:
    return any(re.match(r"^\w+\[\w+\]$", str(d)) for d in shape)


def _build_loops(shape: list[Any]) -> list[tuple[str, str]]:
    """Return [(index_var, range_expr)] for each shape dimension."""
    parsed: list[dict[str, Any]] = []
    for d in shape:
        m = re.match(r"^(\w+)\[(\w+)\]$", str(d))
        if m:
            parsed.append(
                {"ragged": True, "array": m.group(1), "indexed_by": m.group(2)}
            )
        else:
            parsed.append({"ragged": False, "param": str(d)})

    def _suggest_idx(param: str) -> str:
        if param.startswith("n_") and len(param) > 2:
            return param[2:].lower()[0]
        return param.lower()[0]

    used: set[str] = set()
    idx_vars: list[str] = []
    for p in parsed:
        base: str = p["array"] if p["ragged"] else p["param"]
        cand = _suggest_idx(base)
        if cand in used:
            for fb in "ijklmn":
                if fb not in used:
                    cand = fb
                    break
        used.add(cand)
        idx_vars.append(cand)

    param_to_idx = {
        p["param"]: idx for p, idx in zip(parsed, idx_vars) if not p["ragged"]
    }

    loops: list[tuple[str, str]] = []
    for p, idx in zip(parsed, idx_vars):
        if p["ragged"]:
            outer = param_to_idx[p["indexed_by"]]
            loops.append((idx, f"range({p['array']}[{outer}])"))
        else:
            loops.append((idx, f"range({p['param']})"))
    return loops


def _var_decl(name: str, var: dict[str, Any]) -> str:
    vtype = _gurobi_type(var)
    indices = var.get("indices")
    if indices is not None:
        return f'{name} = model.addVars([{indices}], vtype={vtype}, name="{name}")'
    shape = list(var.get("shape", []))
    if not shape:
        return f'{name} = model.addVar(vtype={vtype}, name="{name}")'
    if _has_ragged(shape):
        loops = _build_loops(shape)
        key = (
            "({})".format(", ".join(idx for idx, _ in loops))
            if len(loops) > 1
            else loops[0][0]
        )
        name_fmt = "_".join(f"{{{idx}}}" for idx, _ in loops)
        loop_str = " ".join(f"for {idx} in {rng}" for idx, rng in loops)
        return (
            f"{name} = {{{key}: model.addVar("
            f'vtype={vtype}, name=f"{name}_{name_fmt}") {loop_str}}}'
        )
    dims = ", ".join(str(d) for d in shape)
    return f'{name} = model.addVars({dims}, vtype={vtype}, name="{name}")'


def _solution_extraction(name: str, var: dict[str, Any]) -> list[str]:
    if var.get("indices") is not None:
        return [
            f'variables["{name}"] = {{"kind": "indexed", "data": {{json.dumps(list(k)): {name}[k].x for k in {name}}}}}'  # noqa: E501
        ]
    shape = list(var.get("shape", []))
    if not shape:
        return [f'variables["{name}"] = {{"kind": "scalar", "data": {name}.x}}']
    if _has_ragged(shape):
        loops = _build_loops(shape)
        idx_tuple = ", ".join(idx for idx, _ in loops)
        result: str = f"{name}[{idx_tuple}].x"
        for idx, rng in reversed(loops):
            result = f"[{result} for {idx} in {rng}]"
        return [f'variables["{name}"] = {{"kind": "array", "data": {result}}}']
    if len(shape) == 1:
        d = shape[0]
        return [
            f'variables["{name}"] = {{"kind": "array", "shape": [{d}], "data": [{name}[i].x for i in range({d})]}}'  # noqa: E501
        ]
    if len(shape) == 2:
        d1, d2 = shape
        return [
            f'variables["{name}"] = {{"kind": "array", "shape": [{d1}, {d2}], '
            f'"data": [[{name}[i, j].x for j in range({d2})] for i in range({d1})]}}'
        ]
    iters = ["i", "j", "k", "l"][: len(shape)]
    idx = ", ".join(iters)
    result = f"{name}[{idx}].x"
    for iter_var, dim in reversed(list(zip(iters, shape))):
        result = f"[{result} for {iter_var} in range({dim})]"
    shape_str = ", ".join(str(d) for d in shape)
    return [
        f'variables["{name}"] = {{"kind": "array", "shape": [{shape_str}], "data": {result}}}'  # noqa: E501
    ]


def generate(formulation_json: dict[str, Any]) -> str:
    """Return the complete ``solve.py`` source for a formulation.

    The output is a self-contained Python script that
    loads ``parameters.json``, builds a Gurobi model, solves it, and writes
    ``solution.json``. The script accepts two positional CLI arguments
    (``params`` and ``solution`` paths) so it can also be invoked directly.

    Parameters
    ----------
    formulation_json : dict
        Parsed ``formulation.json`` payload. The relevant keys are
        ``parameters``, ``assumptions``, ``definitions``, ``variables``,
        ``constraints``, ``objective``, and (optional) ``imports``.

    Returns
    -------
    str
        Source code of the generated ``solve.py``.

    Examples
    --------
    >>> from formulation_bench import Dataset
    >>> ds = Dataset("dataset")                          # doctest: +SKIP
    >>> from formulation_bench.codegen import generate
    >>> src = generate(ds.problems[1].formulations["a"]._raw)  # doctest: +SKIP
    >>> "model.optimize()" in src                        # doctest: +SKIP
    True
    """
    params = dict(formulation_json.get("parameters", {}))
    assumptions = list(formulation_json.get("assumptions", []))
    definitions = dict(formulation_json.get("definitions", {}))
    variables = dict(formulation_json.get("variables", {}))
    constraints = list(formulation_json.get("constraints", []))
    objective = dict(formulation_json.get("objective", {}))
    extra_imports = list(formulation_json.get("imports", []))

    explicit_constraints = [c for c in constraints if c.get("explicit", True)]
    implicit_constraints = [c for c in constraints if not c.get("explicit", True)]

    all_codes = [str(c.get("code", {}).get("gurobipy", "")) for c in constraints] + [
        str(objective.get("code", {}).get("gurobipy", ""))
    ]
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
    for imp in extra_imports:
        L.append(str(imp))
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
        for name in params:
            L.append(f'    {name} = data["{name}"]')
        L.append("")

    # Parameter Validation
    if assumptions:
        L.append("    # Parameter Validation")
        for a in assumptions:
            a = dict(a)
            code = str(a.get("code", {}).get("python", "")).strip()
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Definitions
    if definitions:
        L.append("    # Definitions")
        for name, d in definitions.items():
            d = dict(d)
            code = str(d.get("code", {}).get("python", "")).strip()
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Variables
    if variables:
        L.append("    # Variables")
        for name, v in variables.items():
            v = dict(v)
            L.append(f"    {_var_decl(name, v)}")
        L.append("")

    # Constraints
    L.append("    # Constraints")
    for c in explicit_constraints:
        c = dict(c)
        code = str(c.get("code", {}).get("gurobipy", "")).strip()
        if code:
            for line in code.split("\n"):
                L.append(f"    {line}")
    L.append("")

    # Implicit Constraints
    if implicit_constraints:
        L.append("    # Implicit Constraints")
        for c in implicit_constraints:
            c = dict(c)
            code = str(c.get("code", {}).get("gurobipy", "")).strip()
            if code:
                for line in code.split("\n"):
                    L.append(f"    {line}")
        L.append("")

    # Objective
    obj_code = str(objective.get("code", {}).get("gurobipy", "")).strip()
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
        v = dict(v)
        for line in _solution_extraction(name, v):
            L.append(f"    {line}")
    L.append('    solution["variables"] = variables')
    L.append('    solution["objective"] = model.objVal')
    L.append('    with open(solution_path, "w") as f:')
    L.append("        json.dump(solution, f, indent=4)")
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

    return "\n".join(L)
