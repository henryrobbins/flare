"""Fixtures for harness integration tests.

These tests make real model calls. They are marked `harness` and skipped
unless `pytest -m harness` is passed.
"""

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT
