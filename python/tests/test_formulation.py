from pathlib import Path

import pytest

from milp_eq_tools import Assumption, Constraint, Definition, Objective, Parameter, Problem, Variable, VariableType
from milp_eq_tools.formulation import Formulation

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset" / "problems"


@pytest.fixture
def formulation_a(problem1: Problem) -> Formulation:
    return problem1.formulations["a"]


@pytest.fixture
def formulation_with_definitions() -> Formulation:
    """p8.a has a non-empty definitions field."""
    return Formulation(DATASET_ROOT / "p8" / "formulations" / "a")


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


def test_variable_type_integer() -> None:
    # Find a formulation with an integer variable
    for problem_dir in sorted(DATASET_ROOT.iterdir()):
        formulations_dir = problem_dir / "formulations"
        if not formulations_dir.exists():
            continue
        for f_dir in formulations_dir.iterdir():
            f = Formulation(f_dir)
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


