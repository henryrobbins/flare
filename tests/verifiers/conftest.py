"""Fixtures for verifier unit tests.

These tests stub out the LLM client and the FLARE agent harness so each
verifier can be exercised end-to-end without real model calls or Docker.
"""

from pathlib import Path

import pytest
from formulation_bench import Dataset

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def dataset() -> Dataset:
    return Dataset.load(cache_dir=REPO_ROOT / "dataset")
