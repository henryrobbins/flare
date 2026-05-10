"""Fixtures for harness integration tests.

These tests make real model calls. They are marked `harness` and skipped
unless `pytest -m harness` is passed.
"""

import os
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture
def test_model() -> str:
    """Override via env var to test against a different model."""
    return os.environ.get("FLARE_TEST_MODEL", "claude-haiku-4-5")


@pytest.fixture
def test_effort() -> str:
    # Anthropic adaptive thinking effort: low|medium|high|xhigh|max.
    return os.environ.get("FLARE_TEST_EFFORT", "low")
