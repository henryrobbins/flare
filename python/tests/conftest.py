from pathlib import Path

import pytest

from milp_eq_tools import Problem

DATASET_ROOT = Path(__file__).parent.parent.parent / "dataset" / "problems"


@pytest.fixture
def problem1() -> Problem:
    return Problem(DATASET_ROOT / "1")
