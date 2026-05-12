"""Fixtures for verifier unit tests.

These tests stub out the LLM client and the FLARE agent harness so each
verifier can be exercised end-to-end without real model calls or Docker.
"""

from pathlib import Path

import pytest
from formulation_bench import Dataset

REPO_ROOT = Path(__file__).resolve().parents[2]
DATASET_ROOT = REPO_ROOT / "dataset"


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture(scope="session")
def dataset() -> Dataset:
    return Dataset(DATASET_ROOT)
