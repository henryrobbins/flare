from milp_eq_tools import Dataset, Problem


def test_problems_keys(dataset: Dataset) -> None:
    assert set(dataset.problems.keys()) == {1, 2, 3, 4, 5}


def test_problems_values_are_problem_instances(dataset: Dataset) -> None:
    for p in dataset.problems.values():
        assert isinstance(p, Problem)


def test_problem_lookup(dataset: Dataset) -> None:
    p = dataset.problems[1]
    assert p.metadata["source"] == "EquivaFormulation"
