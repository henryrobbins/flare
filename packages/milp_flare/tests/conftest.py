"""Fixtures for milp_flare tests.

The flare verifier needs the monorepo root for the Lake skeleton it copies
into each agent working directory (Common.lean, lakefile.toml,
lean-toolchain, lake-manifest.json) and for the dataset's ground-truth
Lean files used by ``DummyHarness`` / ``GroundTruthHarness``. Once the
package is decoupled from the monorepo this fixture will go away in
favor of bundled assets.
"""

from pathlib import Path

import pytest
from dotenv import load_dotenv
from formulation_bench import Dataset

REPO_ROOT = Path(__file__).resolve().parents[3]
DATASET_ROOT = REPO_ROOT / "dataset"

# Harness integration tests read provider API keys from the parent process
# env (e.g. OpenCode reads ANTHROPIC_API_KEY directly from os.environ).
# Load .env up-front rather than requiring callers to export the keys.
load_dotenv(REPO_ROOT / ".env")


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture(scope="session")
def dataset() -> Dataset:
    return Dataset(DATASET_ROOT)
