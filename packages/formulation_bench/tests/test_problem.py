from pathlib import Path

import pytest

from formulation_bench import Dataset, Parameter, Problem, Solution
from formulation_bench.formulation import Formulation

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset"


@pytest.fixture
def problem11(dataset: Dataset) -> Problem:
    return dataset.problems[11]


def test_name_loaded(problem1: Problem) -> None:
    assert problem1.name == "Amusement Park Ticket Machines"


def test_name_loaded_when_present(problem11: Problem) -> None:
    assert problem11.name == "Sub-Hour Unit Commitment (SHUC)"


def test_metadata_loaded_eagerly(problem1: Problem) -> None:
    source = problem1.metadata["source"]
    assert source["dataset"] == "EquivaFormulation"
    assert source["instance_id"] == 47


def test_parameters_loaded_eagerly(problem1: Problem) -> None:
    assert "CashMachineProcessingRate" in problem1.parameters
    p = problem1.parameters["CashMachineProcessingRate"]
    assert isinstance(p, Parameter)
    assert p.shape == []
    assert "people per hour" in p.description


def test_description_lazy(problem1: Problem) -> None:
    assert "description" not in problem1.__dict__
    desc = problem1.description
    assert isinstance(desc, str)
    assert len(desc) > 0
    assert "description" in problem1.__dict__


def test_description_cached(problem1: Problem) -> None:
    assert problem1.description is problem1.description


def test_data_lazy(problem1: Problem) -> None:
    assert "data" not in problem1.__dict__
    data = problem1.data
    assert isinstance(data, dict)
    assert "CashMachineProcessingRate" in data
    assert "data" in problem1.__dict__


def test_data_cached(problem1: Problem) -> None:
    assert problem1.data is problem1.data


def test_formulations_lazy(dataset: Dataset) -> None:
    p = Problem(dataset.root / "problems" / "p1")
    assert "formulations" not in p.__dict__
    formulations = p.formulations
    assert isinstance(formulations, dict)
    assert "formulations" in p.__dict__


def test_formulations_cached(problem1: Problem) -> None:
    assert problem1.formulations is problem1.formulations


def test_formulations_keys(problem1: Problem) -> None:
    keys = list(problem1.formulations.keys())
    assert "a" in keys
    assert "j" in keys
    assert len(keys) == 10


def test_formulations_values_are_formulation_instances(problem1: Problem) -> None:
    for f in problem1.formulations.values():
        assert isinstance(f, Formulation)


def test_solution_lazy(problem1: Problem) -> None:
    assert "solution" not in problem1.__dict__
    solution = problem1.solution
    assert solution is not None
    assert "solution" in problem1.__dict__


def test_solution_cached(problem1: Problem) -> None:
    assert problem1.solution is problem1.solution


def test_solution_is_solution_instance(problem1: Problem) -> None:
    assert isinstance(problem1.solution, Solution)


def test_solution_values(problem1: Problem) -> None:
    s = problem1.solution
    assert s is not None
    assert s.objective == 20.0
    assert s.variables == {"NumCashMachines": 10.0, "NumCardMachines": 10.0}


def test_solution_none_when_missing(tmp_path: "Path") -> None:

    problem_dir = tmp_path / "prob"
    problem_dir.mkdir()
    (problem_dir / "problem.json").write_text(
        '{"name": "Test Problem", "description": "test",'
        ' "parameters": {}, "metadata": {}}'
    )
    (problem_dir / "description.md").write_text("test")
    p = Problem(problem_dir)
    assert p.solution is None
