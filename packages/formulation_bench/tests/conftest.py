from pathlib import Path

import pytest

from formulation_bench import Dataset, Problem

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset"


@pytest.fixture
def dataset() -> Dataset:
    return Dataset(DATASET_ROOT)


@pytest.fixture
def problem1(dataset: Dataset) -> Problem:
    return dataset.problems[1]
