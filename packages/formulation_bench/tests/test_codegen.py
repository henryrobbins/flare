"""Codegen + end-to-end solve tests for a representative set of formulations.

``Formulation.gen_solve_py`` (backed by :mod:`formulation_bench._codegen`) only
has a single doctest covering p12, which uses one narrow shape of formulation.
The four problems below collectively exercise every branch of the codegen that
is reachable from real dataset formulations:

* **p8**  — indexed and scalar variables, ``definitions``, ``Model``-style imports
* **p9**  — extra ``imports``, ``gp``-style imports, 1-D arrays, implicit constraints
* **p11** — ragged variables (drives ``_codegen._build_loops``)
* **p20** — 3-D+ arrays

Each formulation is code-generated, compiled, run end to end
(``gen_params`` -> generated ``solve.py``), and -- when the formulation is
valid -- checked against the objective recorded in the dataset.

The only ``_codegen`` lines not reached this way are the index-letter collision
fallback in ``_build_loops``, which no real formulation triggers; see
``test_build_loops_index_collision`` for a direct unit test of that path.
"""

from __future__ import annotations

import json
import math
import subprocess
import sys
from pathlib import Path

import pytest

from formulation_bench import Dataset
from formulation_bench._codegen import _build_loops
from formulation_bench.formulation import Formulation
from formulation_bench.models import Shape, Variable

#: Problems whose formulations together cover every reachable codegen branch.
CODEGEN_PROBLEMS = (8, 9, 11, 20)

#: Relative tolerance when comparing solved objectives to recorded ones.
OBJECTIVE_REL_TOL = 1e-6

DATASET_ROOT = Path(__file__).resolve().parents[3] / "dataset"

# A module-level Dataset is needed so formulations can be enumerated at
# collection time for parametrization.
_DATASET = Dataset(DATASET_ROOT)

CODEGEN_FORMULATIONS = [
    pytest.param(f, id=f"p{pid}.{fid}")
    for pid in CODEGEN_PROBLEMS
    for fid, f in _DATASET.problems[pid].formulations.items()
]


def _var_kind(v: Variable) -> str:
    """Classify a variable the way ``_codegen`` branches on it."""
    if v.indices is not None:
        return "indexed"
    shape = v.shape
    if shape.is_scalar:
        return "scalar"
    if shape.is_ragged:
        return "ragged"
    return {1: "1d", 2: "2d"}.get(len(shape), "3d+")


def test_codegen_problems_stay_representative() -> None:
    """Guard that ``CODEGEN_PROBLEMS`` still spans every codegen case.

    If a dataset edit removes the last example of some case (e.g. the only
    ragged or 3-D variable), the per-formulation tests below would silently
    stop covering that codegen branch. This test fails loudly instead.
    """
    formulations = [
        f
        for pid in CODEGEN_PROBLEMS
        for f in _DATASET.problems[pid].formulations.values()
    ]

    var_kinds = {_var_kind(v) for f in formulations for v in f.variables.values()}
    assert var_kinds == {"scalar", "1d", "2d", "3d+", "ragged", "indexed"}

    assert any(f.definitions for f in formulations), "no formulation with definitions"
    assert any(f.imports for f in formulations), "no formulation with extra imports"

    import_styles = {
        "gp" if "gp." in f.gen_solve_py() else "Model" for f in formulations
    }
    assert import_styles == {"gp", "Model"}


@pytest.mark.parametrize("formulation", CODEGEN_FORMULATIONS)
def test_gen_solve_py_compiles(formulation: Formulation) -> None:
    """The generated ``solve.py`` is syntactically valid Python."""
    script = formulation.gen_solve_py()
    compile(script, f"<{formulation.path.name}/solve.py>", "exec")


@pytest.mark.parametrize("formulation", CODEGEN_FORMULATIONS)
def test_solve_matches_recorded_objective(
    formulation: Formulation, tmp_path: Path
) -> None:
    """gen_params -> generated solve.py runs and reproduces the recorded objective.

    Artifacts are written under ``tmp_path`` so the dataset tree is never
    mutated. The objective is only checked for valid formulations; invalid
    formulations are unfaithful by construction, but their generated code must
    still execute.
    """
    solve_py = tmp_path / "solve.py"
    solve_py.write_text(formulation.gen_solve_py())

    params = tmp_path / "parameters.json"
    formulation.run_gen_params(output_path=params)

    solution = tmp_path / "solution.json"
    subprocess.run(
        [sys.executable, str(solve_py), str(params), str(solution)],
        check=True,
    )

    if not formulation.valid:
        return
    expected = formulation.problem.solution
    if expected is None:
        return
    actual = json.loads(solution.read_text())["objective"]
    assert math.isclose(actual, expected.objective, rel_tol=OBJECTIVE_REL_TOL), (
        f"{formulation.path.name}: got {actual}, expected {expected.objective}"
    )


def test_build_loops_index_collision() -> None:
    """``_build_loops`` falls back to a free letter when indices collide.

    No real dataset formulation has a ragged variable whose dimensions
    suggest the same index letter, so this branch is covered directly: two
    ragged dimensions over arrays ``cars`` and ``crates`` both suggest ``c``.
    """
    shape = Shape.parse(["n", "cars[n]", "crates[n]"])
    idx_vars = [idx for idx, _ in _build_loops(shape)]
    assert len(idx_vars) == len(set(idx_vars)), "index variables must be distinct"
    assert idx_vars[1] == "c"
    assert idx_vars[2] != "c"
