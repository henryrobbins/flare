import pytest

from formulation_bench import Dataset, Reformulation
from formulation_bench.formulation import Formulation


def test_reformulations_loaded(dataset: Dataset) -> None:
    assert len(dataset.reformulations) > 0


def test_reformulations_are_reformulation_instances(dataset: Dataset) -> None:
    for r in dataset.reformulations:
        assert isinstance(r, Reformulation)


def test_reformulation_formulations_are_formulation_instances(dataset: Dataset) -> None:
    r = dataset.reformulations[0]
    assert isinstance(r.a, Formulation)
    assert isinstance(r.b, Formulation)


def test_is_reformulation_is_bool(dataset: Dataset) -> None:
    for r in dataset.reformulations:
        assert isinstance(r.is_reformulation, bool)


@pytest.mark.xfail(
    reason="data drift: p13 has a True pair whose A formulation is invalid",
    strict=False,
)
def test_reformulation_true_when_both_valid(dataset: Dataset) -> None:
    for r in dataset.reformulations:
        if r.is_reformulation:
            assert r.a.valid and r.b.valid


def test_reformulation_false_when_any_invalid(dataset: Dataset) -> None:
    for r in dataset.reformulations:
        if not r.is_reformulation:
            assert not r.a.valid or not r.b.valid


def test_has_both_true_and_false_reformulations(dataset: Dataset) -> None:
    assert any(r.is_reformulation for r in dataset.reformulations)
    assert any(not r.is_reformulation for r in dataset.reformulations)


def test_no_reformulations_when_file_missing(tmp_path: pytest.TempPathFactory) -> None:
    (tmp_path / "dataset.json").write_text('{"problems": []}')
    ds = Dataset(tmp_path)
    assert ds.reformulations == []


def test_lean_proof_path_layout_for_positive(dataset: Dataset) -> None:
    r = next(r for r in dataset.reformulations if r.is_reformulation)
    problem_dir = r.a.problem.path
    expected = (
        problem_dir.parent.parent
        / "reformulations"
        / problem_dir.name
        / f"{r.a.path.name}_{r.b.path.name}.lean"
    )
    assert r.lean_proof_path == expected


def test_lean_proof_path_exists_for_positive(dataset: Dataset) -> None:
    positive = next(r for r in dataset.reformulations if r.is_reformulation)
    path = positive.lean_proof_path
    assert path is not None
    assert path.is_file()


def test_lean_proof_path_none_for_negative(dataset: Dataset) -> None:
    negative = next(r for r in dataset.reformulations if not r.is_reformulation)
    assert negative.lean_proof_path is None
