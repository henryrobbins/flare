from pathlib import Path

import pytest

from milp_eq_tools import Constraint, Objective, Parameter, Problem, Variable, VariableType
from milp_eq_tools.formulation import Formulation

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset" / "problems"


@pytest.fixture
def formulation_a(problem1: Problem) -> Formulation:
    return problem1.formulations["a"]


def test_valid(formulation_a: Formulation) -> None:
    assert formulation_a.valid is True


def test_metadata(formulation_a: Formulation) -> None:
    assert formulation_a.metadata["source"] == "EquivaFormulation"
    assert "variation_id" in formulation_a.metadata


def test_parameters(formulation_a: Formulation) -> None:
    assert "CashMachineProcessingRate" in formulation_a.parameters
    p = formulation_a.parameters["CashMachineProcessingRate"]
    assert isinstance(p, Parameter)
    assert p.shape == []


def test_variables(formulation_a: Formulation) -> None:
    assert "NumCashMachines" in formulation_a.variables
    v = formulation_a.variables["NumCashMachines"]
    assert isinstance(v, Variable)
    assert v.type == VariableType.continuous
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
    assert len(formulation_a.constraints) == 3
    c = formulation_a.constraints[0]
    assert isinstance(c, Constraint)
    assert isinstance(c.description, str)
    assert isinstance(c.formulation, str)
    assert "gurobipy" in c.code


def test_objective(formulation_a: Formulation) -> None:
    obj = formulation_a.objective
    assert isinstance(obj, Objective)
    assert "Minimize" in obj.description or "minimize" in obj.description.lower()
    assert "gurobipy" in obj.code


def test_description_lazy(formulation_a: Formulation) -> None:
    assert "description" not in formulation_a.__dict__
    desc = formulation_a.description
    assert isinstance(desc, str)
    assert len(desc) > 0
    assert "description" in formulation_a.__dict__


def test_description_cached(formulation_a: Formulation) -> None:
    first = formulation_a.description
    second = formulation_a.description
    assert first is second
