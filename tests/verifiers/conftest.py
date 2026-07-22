"""Fixtures for verifier unit tests.

These tests stub out the LLM client and the FLARE agent harness so each
verifier can be exercised end-to-end without real model calls or Docker.
"""

import pytest
from formulation_bench import Dataset


@pytest.fixture(scope="session")
def dataset() -> Dataset:
    return Dataset.load()
