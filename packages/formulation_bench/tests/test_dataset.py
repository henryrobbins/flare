from formulation_bench import Dataset, Problem


def test_problems_keys(dataset: Dataset) -> None:
    keys = set(dataset.problems.keys())
    assert keys, "dataset should expose at least one problem"
    assert keys == set(range(1, max(keys) + 1)), (
        f"problem ids should form a contiguous range from 1, got {sorted(keys)}"
    )


def test_problems_values_are_problem_instances(dataset: Dataset) -> None:
    for p in dataset.problems.values():
        assert isinstance(p, Problem)


def test_problem_lookup(dataset: Dataset) -> None:
    p = dataset.problems[1]
    assert p.metadata["source"]["dataset"] == "EquivaFormulation"
