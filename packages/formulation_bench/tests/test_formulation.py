from pathlib import Path

import pytest

from formulation_bench import (
    Assumption,
    Constraint,
    Dataset,
    Definition,
    Objective,
    Parameter,
    Problem,
    Variable,
    VariableType,
)
from formulation_bench.formulation import Formulation

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset"


@pytest.fixture
def formulation_a(problem1: Problem) -> Formulation:
    return problem1.formulations["a"]


@pytest.fixture
def formulation_with_definitions(dataset: Dataset) -> Formulation:
    """p8.a has a non-empty definitions field."""
    return dataset.problems[8].formulations["a"]


@pytest.fixture
def formulation_with_imports(dataset: Dataset) -> Formulation:
    """p6.f has a non-empty imports field."""
    return dataset.problems[6].formulations["f"]


def test_valid(formulation_a: Formulation) -> None:
    assert formulation_a.valid is True


def test_metadata(formulation_a: Formulation) -> None:
    source = formulation_a.metadata["source"]
    assert source["dataset"] == "EquivaFormulation"
    assert "variation_id" in source


def test_parameters(formulation_a: Formulation) -> None:
    assert "CashMachineProcessingRate" in formulation_a.parameters
    p = formulation_a.parameters["CashMachineProcessingRate"]
    assert isinstance(p, Parameter)
    assert p.shape == []


def test_variables(formulation_a: Formulation) -> None:
    assert "NumCashMachines" in formulation_a.variables
    v = formulation_a.variables["NumCashMachines"]
    assert isinstance(v, Variable)
    assert v.type == VariableType.integer
    assert v.shape == []


def test_variable_type_integer(dataset: Dataset) -> None:
    for problem in dataset.problems.values():
        for f in problem.formulations.values():
            for v in f.variables.values():
                if v.type == VariableType.integer:
                    assert v.type == VariableType.integer
                    return
    pytest.fail("No integer variable found in dataset")


def test_constraints(formulation_a: Formulation) -> None:
    assert len(formulation_a.constraints) == 5
    c = formulation_a.constraints[0]
    assert isinstance(c, Constraint)
    assert isinstance(c.description, str)
    assert isinstance(c.formulation, str)
    assert isinstance(c.explicit, bool)
    assert "gurobipy" in c.code


def test_constraints_explicit_flag(formulation_a: Formulation) -> None:
    explicit = [c for c in formulation_a.constraints if c.explicit]
    implicit = [c for c in formulation_a.constraints if not c.explicit]
    assert len(explicit) == 3
    assert len(implicit) == 2


def test_assumptions(formulation_a: Formulation) -> None:
    assert len(formulation_a.assumptions) == 6
    a = formulation_a.assumptions[0]
    assert isinstance(a, Assumption)
    assert isinstance(a.description, str)
    assert isinstance(a.formulation, str)
    assert isinstance(a.explicit, bool)
    assert "python" in a.code


def test_assumptions_all_implicit(formulation_a: Formulation) -> None:
    assert all(not a.explicit for a in formulation_a.assumptions)


def test_objective(formulation_a: Formulation) -> None:
    obj = formulation_a.objective
    assert isinstance(obj, Objective)
    assert "Minimize" in obj.description or "minimize" in obj.description.lower()
    assert "gurobipy" in obj.code


def test_definitions_empty(formulation_a: Formulation) -> None:
    assert formulation_a.definitions == {}


def test_definitions_parsed(formulation_with_definitions: Formulation) -> None:
    defs = formulation_with_definitions.definitions
    assert len(defs) > 0
    for name, d in defs.items():
        assert isinstance(name, str)
        assert isinstance(d, Definition)
        assert isinstance(d.description, str)
        assert isinstance(d.code, dict)
        assert "python" in d.code


def test_definitions_keys(formulation_with_definitions: Formulation) -> None:
    assert "P" in formulation_with_definitions.definitions
    assert "M" in formulation_with_definitions.definitions


def test_definitions_code(formulation_with_definitions: Formulation) -> None:
    p_def = formulation_with_definitions.definitions["P"]
    assert "P" in p_def.code["python"]
    m_def = formulation_with_definitions.definitions["M"]
    assert "M" in m_def.code["python"]


def test_imports_empty(formulation_a: Formulation) -> None:
    assert formulation_a.imports == []


def test_imports_parsed(formulation_with_imports: Formulation) -> None:
    imports = formulation_with_imports.imports
    assert len(imports) > 0
    assert all(isinstance(s, str) for s in imports)


def test_imports_content(formulation_with_imports: Formulation) -> None:
    assert "import math" in formulation_with_imports.imports


def test_problem_back_reference(problem1: Problem, formulation_a: Formulation) -> None:
    assert formulation_a.problem is problem1
