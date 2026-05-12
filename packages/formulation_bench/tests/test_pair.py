import pytest

from formulation_bench import Dataset, Pair
from formulation_bench.formulation import Formulation


def test_pairs_loaded(dataset: Dataset) -> None:
    assert len(dataset.pairs) > 0


def test_pairs_are_pair_instances(dataset: Dataset) -> None:
    for pair in dataset.pairs:
        assert isinstance(pair, Pair)


def test_pair_formulations_are_formulation_instances(dataset: Dataset) -> None:
    pair = dataset.pairs[0]
    assert isinstance(pair.a, Formulation)
    assert isinstance(pair.b, Formulation)


def test_pair_reformulation_is_bool(dataset: Dataset) -> None:
    for pair in dataset.pairs:
        assert isinstance(pair.reformulation, bool)


def test_reformulation_true_when_both_valid(dataset: Dataset) -> None:
    for pair in dataset.pairs:
        if pair.reformulation:
            assert pair.a.valid and pair.b.valid


def test_reformulation_false_when_any_invalid(dataset: Dataset) -> None:
    for pair in dataset.pairs:
        if not pair.reformulation:
            assert not pair.a.valid or not pair.b.valid


def test_has_both_true_and_false_pairs(dataset: Dataset) -> None:
    assert any(p.reformulation for p in dataset.pairs)
    assert any(not p.reformulation for p in dataset.pairs)


def test_no_pairs_when_file_missing(tmp_path: pytest.TempPathFactory) -> None:
    (tmp_path / "dataset.json").write_text('{"problems": []}')
    ds = Dataset(tmp_path)
    assert ds.pairs == []
