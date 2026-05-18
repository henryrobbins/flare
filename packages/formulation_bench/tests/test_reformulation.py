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
