from formulation_bench import Dataset, Problem


def test_problems_keys(dataset: Dataset) -> None:
    assert set(dataset.problems.keys()) == set(range(1, 13))


def test_problems_values_are_problem_instances(dataset: Dataset) -> None:
    for p in dataset.problems.values():
        assert isinstance(p, Problem)


def test_problem_lookup(dataset: Dataset) -> None:
    p = dataset.problems[1]
    assert p.metadata["source"]["dataset"] == "EquivaFormulation"
