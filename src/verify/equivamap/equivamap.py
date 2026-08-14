import dataclasses
import json
import subprocess
import time
from pathlib import Path
from typing import Any

from formulation_bench import Formulation, Reformulation
from formulation_bench.models import Constraint

from src.llm_client import LLMClient, TruncatedResponseError, compute_cost_usd
from src.verify.base import ReformulationResult, SynchronousVerifier
from src.verify.equivamap.prompts import (
    VARIABLE_MAPPING_SCHEMA,
    problem_info,
    render_variable_mapping,
)

TOLERANCE = 1e-6


Nested = float | list[Any]


class MappingError(Exception):
    """A proposed variable mapping cannot be evaluated into pinning values."""


def _scale_nested(data: Nested, c: float) -> Nested:
    if isinstance(data, list):
        return [_scale_nested(v, c) for v in data]
    return c * float(data)


def _add_nested(a: Nested, b: Nested) -> Nested:
    if isinstance(a, list) != isinstance(b, list):
        raise MappingError("terms of the mapping have different ranks")
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            raise MappingError("terms of the mapping have different shapes")
        return [_add_nested(x, y) for x, y in zip(a, b)]
    assert not isinstance(a, list) and not isinstance(b, list)
    return float(a) + float(b)


def _nested_structure(data: Nested) -> Any:
    """Nesting structure of a solution value, ragged arrays included."""
    if not isinstance(data, list):
        return None
    return tuple(_nested_structure(v) for v in data)


def _compute_rhs(
    terms: list[dict[str, Any]], sol_b_vars: dict[str, Any]
) -> float | list[Any] | dict[Any, Any]:
    """Compute RHS value(s) by evaluating the linear combination against B's sol.

    Raises ``MappingError`` if the terms cannot be combined into a single value.
    """
    result: float | list[Any] | dict[Any, Any] | None = None
    kinds = set()
    for term in terms:
        entry = sol_b_vars.get(term["variable"])
        if entry is None:
            raise MappingError(f"{term['variable']} is not a variable of B")
        c = term["constant"]
        kind = entry["kind"]
        kinds.add(kind)
        if len(kinds) > 1:
            raise MappingError("terms of the mapping have different kinds")
        data = entry["data"]
        if kind == "scalar":
            contrib: float = c * float(data)
            result = (float(result) if result is not None else 0.0) + contrib  # type: ignore[arg-type]
        elif kind == "array":
            scaled = _scale_nested(data, c)
            result = _add_nested(result, scaled) if result is not None else scaled  # type: ignore[arg-type]
        elif kind == "indexed":
            contrib_d = {tuple(json.loads(k)): c * float(v) for k, v in data.items()}
            if result is None:
                result = contrib_d
            else:
                assert isinstance(result, dict)
                if set(contrib_d) != set(result):
                    raise MappingError("terms of the mapping have different index sets")
                result = {k: result.get(k, 0.0) + v for k, v in contrib_d.items()}
    if result is None:
        raise MappingError("mapping produced no value")
    return result


def _check_pinnable(
    var_name: str, rhs: float | list[Any] | dict[Any, Any], entry_a: dict[str, Any]
) -> None:
    """Raise ``MappingError`` unless rhs pins every entry of A's ``var_name``.

    A mapping whose value doesn't line up with the variable it pins would
    otherwise silently under-constrain A, which reads as equivalence.
    """
    kind = entry_a["kind"]
    if kind == "scalar":
        if isinstance(rhs, (list, dict)):
            raise MappingError(f"{var_name} is scalar but the mapping is not")
    elif kind == "array":
        if not isinstance(rhs, list):
            raise MappingError(f"{var_name} is an array but the mapping is not")
        if _nested_structure(rhs) != _nested_structure(entry_a["data"]):
            raise MappingError(f"the mapping does not match the shape of {var_name}")
    else:
        keys = {tuple(json.loads(k)) for k in entry_a["data"]}
        if not isinstance(rhs, dict) or set(rhs) != keys:
            raise MappingError(f"the mapping does not cover every index of {var_name}")


def _list_depth(data: list[Any]) -> int:
    if data and isinstance(data[0], list):
        return 1 + _list_depth(data[0])
    return 1


def _pinning_constraint(
    var_name: str, rhs: float | list[Any] | dict[Any, Any]
) -> Constraint:
    """Build a single Constraint that pins var_name to the given RHS value(s)."""
    if isinstance(rhs, (int, float)):
        code = f"model.addConstr({var_name} == {rhs!r})"
        formulation = f"{var_name} = {rhs}"
    elif isinstance(rhs, list):
        depth = _list_depth(rhs)
        idx = [f"_i{d}" for d in range(depth)]
        it = [f"_it{d}" for d in range(depth)]
        lines = [f"for {idx[0]}, {it[1] if depth > 1 else '_v'} in enumerate({rhs!r}):"]
        for d in range(1, depth):
            inner = it[d + 1] if d < depth - 1 else "_v"
            lines.append(f"{'    ' * d}for {idx[d]}, {inner} in enumerate({it[d]}):")
        lines.append(
            f"{'    ' * depth}model.addConstr({var_name}[{', '.join(idx)}] == _v)"
        )
        code = "\n".join(lines)
        formulation = f"{var_name}[{', '.join(idx)}] = rhs[...] for all indices"
    else:
        code = f"for _k, _v in {rhs!r}.items(): model.addConstr({var_name}[_k] == _v)"
        formulation = f"{var_name}[k] = rhs[k] for all k"

    return Constraint(
        description=f"Pin {var_name} to B's solution value",
        formulation=formulation,
        explicit=True,
        code={"gurobipy": code},
    )


def _validate_mapping(
    parsed: dict[str, Any], b_variables: dict[str, Any]
) -> list[dict[str, Any]] | None:
    """Validate structured mapping dict. Returns [] for no-mapping, None on invalid."""
    terms = parsed.get("terms")
    if not isinstance(terms, list) or not terms:
        return None
    if terms[0].get("constant") == "none":
        return []
    valid: list[dict[str, Any]] = []
    for term in terms:
        raw = term.get("constant")
        variable = term.get("variable")
        try:
            constant = float(raw)
        except (TypeError, ValueError):
            return None
        if variable not in b_variables:
            return None
        valid.append({"constant": constant, "variable": variable})
    return valid


def _solve(formulation: Formulation, fdir: Path) -> dict[str, Any]:
    """gen_params → write solve.py → run → return solution dict."""
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
    result: dict[str, Any] = json.loads(solution_path.read_text())
    return result


class EquivaMapVerifier(SynchronousVerifier):
    def __init__(self, client: LLMClient) -> None:
        self.client = client

    @property
    def name(self) -> str:
        return "equivamap"

    def get_config_dict(self) -> dict[str, Any]:
        return {"tolerance": TOLERANCE, "llm": dataclasses.asdict(self.client.config)}

    def _verify(self, pair: Reformulation, output_path: Path) -> ReformulationResult:
        # This method compares fixed instances, so the pair's parameter map is ignored.
        a, b = pair.a, pair.b
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.get_config_dict(), indent=2)
        )

        start = time.time()

        # Step 1: Solve A and B independently
        sol_a = _solve(a, artifacts_dir / "a")
        obj_a = float(sol_a["objective"])
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
        variable_mappings: dict[str, list[dict[str, Any]] | None] = {}
        total_input_tokens = 0
        total_output_tokens = 0

        for var_name in a.variables:
            rendered = render_variable_mapping(var_name, a, b)
            (prompts_dir / f"{var_name}_prompt.txt").write_text(rendered.user)
            try:
                parsed, usage = self.client.complete_json_with_usage(
                    rendered.system, rendered.user, VARIABLE_MAPPING_SCHEMA
                )
            except TruncatedResponseError as e:
                (prompts_dir / f"{var_name}_response.partial.txt").write_text(e.partial)
                raise
            total_input_tokens += usage["input_tokens"]
            total_output_tokens += usage["output_tokens"]
            (prompts_dir / f"{var_name}_response.json").write_text(
                json.dumps(parsed, indent=2)
            )
            variable_mappings[var_name] = _validate_mapping(parsed, info_b["variables"])

        (artifacts_dir / "variable_mappings.json").write_text(
            json.dumps(variable_mappings, indent=2)
        )

        def negative(**extra: Any) -> ReformulationResult:
            """Result for a check that never got far enough to compare objectives."""
            meta = {
                "is_reformulation": False,
                "obj_a": obj_a,
                "obj_b": obj_b,
                **extra,
                "input_tokens": total_input_tokens,
                "output_tokens": total_output_tokens,
            }
            (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))
            return ReformulationResult(
                is_reformulation=False,
                method=self.name,
                artifacts_dir=artifacts_dir,
                duration_s=round(time.time() - start, 1),
                cost_usd=compute_cost_usd(
                    self.client.config.model, total_input_tokens, total_output_tokens
                ),
                metadata=meta,
            )

        # If any variable could not be mapped, the check is invalid — return False.
        if any(not terms for terms in variable_mappings.values()):
            return negative(incomplete_mapping=True)

        # Step 4: Compute pinning constraints and build modified formulation A
        map_lines: list[str] = []
        pinned_a = a

        for var_name, terms in variable_mappings.items():
            assert terms is not None
            try:
                rhs = _compute_rhs(terms, sol_b_vars)
                _check_pinnable(var_name, rhs, sol_a["variables"][var_name])
            except MappingError as e:
                return negative(invalid_mapping=str(e))
            constraint = _pinning_constraint(var_name, rhs)
            pinned_a = pinned_a.with_constraint(constraint)
            map_lines.append(constraint.code["gurobipy"])

        (artifacts_dir / "map_constraints.py").write_text("\n".join(map_lines))

        # Step 5: Solve A with pinning constraints
        try:
            sol_a_constrained = _solve(pinned_a, artifacts_dir / "a_constrained")
        except subprocess.CalledProcessError:
            return negative(infeasible=True)
        obj_a_constrained = float(sol_a_constrained["objective"])

        # Step 6: Check that B's optimum, mapped into A's variables, is optimal in A.
        # Comparing against A's own optimum (rather than B's) keeps the test invariant
        # to differences in how A and B express their objectives.
        is_reform = abs(obj_a - obj_a_constrained) < TOLERANCE
        meta = {
            "is_reformulation": is_reform,
            "obj_a": obj_a,
            "obj_b": obj_b,
            "obj_a_constrained": obj_a_constrained,
            "input_tokens": total_input_tokens,
            "output_tokens": total_output_tokens,
        }
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return ReformulationResult(
            is_reformulation=is_reform,
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=round(time.time() - start, 1),
            cost_usd=compute_cost_usd(
                self.client.config.model, total_input_tokens, total_output_tokens
            ),
            metadata=meta,
        )
