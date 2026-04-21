from milp_eq_tools import Parameter, Problem
from milp_eq_tools.formulation import Formulation


def test_metadata_loaded_eagerly(problem1: Problem) -> None:
    assert problem1.metadata["source"] == "EquivaFormulation"
    assert problem1.metadata["instance_id"] == 47


def test_parameters_loaded_eagerly(problem1: Problem) -> None:
    assert "CashMachineProcessingRate" in problem1.parameters
    p = problem1.parameters["CashMachineProcessingRate"]
    assert isinstance(p, Parameter)
    assert p.shape == []
    assert "people per hour" in p.description


def test_description_lazy(problem1: Problem) -> None:
    assert not hasattr(problem1, "_description")
    desc = problem1.description
    assert isinstance(desc, str)
    assert len(desc) > 0
    assert hasattr(problem1, "_description")


def test_description_cached(problem1: Problem) -> None:
    first = problem1.description
    second = problem1.description
    assert first is second


def test_data_lazy(problem1: Problem) -> None:
    assert not hasattr(problem1, "_data")
    data = problem1.data
    assert isinstance(data, dict)
    assert "CashMachineProcessingRate" in data
    assert hasattr(problem1, "_data")


def test_data_cached(problem1: Problem) -> None:
    first = problem1.data
    second = problem1.data
    assert first is second


def test_formulations_lazy(problem1: Problem) -> None:
    assert not hasattr(problem1, "_formulations")
    formulations = problem1.formulations
    assert isinstance(formulations, dict)
    assert hasattr(problem1, "_formulations")


def test_formulations_cached(problem1: Problem) -> None:
    first = problem1.formulations
    second = problem1.formulations
    assert first is second


def test_formulations_keys(problem1: Problem) -> None:
    keys = list(problem1.formulations.keys())
    assert "a" in keys
    assert "j" in keys
    assert len(keys) == 10


def test_formulations_values_are_formulation_instances(problem1: Problem) -> None:
    for f in problem1.formulations.values():
        assert isinstance(f, Formulation)

