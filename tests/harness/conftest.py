"""Fixtures for harness integration tests.

These tests make real model calls. They are marked `harness` and skipped
unless `pytest -m harness` is passed.
"""

from pathlib import Path

import pytest
from dotenv import load_dotenv

REPO_ROOT = Path(__file__).resolve().parents[2]

# Mirror experiments/baseline.py: harnesses inherit the parent process env
# (e.g. OpenCode reads ANTHROPIC_API_KEY directly from os.environ), so
# load .env up-front rather than requiring callers to export the keys.
load_dotenv(REPO_ROOT / ".env")


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT
