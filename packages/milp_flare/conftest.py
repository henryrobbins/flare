"""Fixtures for milp_flare tests and docstring examples.

Documentation examples run FLARE end to end, which normally means Docker, a
provider credential, and a multi-minute model call. :func:`fake_agent` fakes
the *compute* boundary instead: ``DockerRunner.start`` becomes an in-process
handle that writes the files a finished container would have left in the
working directory and streams a canned agent output. Everything above that
boundary -- ``configure_wd``, the credential spec, stream parsing, cost
estimation, and ``FLARE._evaluate`` -- runs for real, so the examples exercise
the real API and fail when it moves.

The fixture is applied automatically to every doctest collected from
``src/milp_flare`` and explicitly by ``tests/test_docs_examples.py``.
"""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path

import pytest
from dotenv import load_dotenv
from formulation_bench import Dataset

from milp_flare.harness.runner import AgentRun, AuthSpec
from milp_flare.harness.runner.docker import DockerRunner

REPO_ROOT = Path(__file__).resolve().parents[2]

# Harness integration tests read provider API keys from the parent process
# env (e.g. OpenCode reads ANTHROPIC_API_KEY directly from os.environ).
# Load .env up-front rather than requiring callers to export the keys.
load_dotenv(REPO_ROOT / ".env")

# Every harness credential a docs example might construct an AuthSpec from.
# The fake runner never uses the values -- `auth_spec` only checks presence.
_PLACEHOLDER_ENV = [
    "CLAUDE_CODE_OAUTH_TOKEN",
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "DEEPSEEK_API_KEY",
]

#: A single `claude -p --output-format stream-json` result event, parsed by
#: `ClaudeCodeHarness._parse_lines` into tokens, cost, and stop reason.
_AGENT_OUTPUT = json.dumps(
    {
        "type": "result",
        "stop_reason": "end_turn",
        "total_cost_usd": 1.49,
        "usage": {"input_tokens": 120000, "output_tokens": 24000},
    }
)

_FORMULATION_LEAN = "def formulation : MILPFormulation := sorry\n"

_REFORMULATION_LEAN = "def reformulation : MILPReformulation := sorry\n"

_COMPILE_LOG = (
    "'reformulation' depends on axioms: [propext, Classical.choice, Quot.sound]\n"
)


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return REPO_ROOT


@pytest.fixture(scope="session")
def dataset() -> Dataset:
    return Dataset.load()


class _FakeAgentRun(AgentRun):
    """In-process stand-in for a container run: one line of canned output."""

    @property
    def stdout(self) -> Iterator[str]:
        yield _AGENT_OUTPUT

    def cancel(self) -> None:
        pass


def _write_agent_outputs(wd: Path) -> None:
    """Write what a successful container run leaves behind in the workdir.

    The Lean files are stubs -- nothing compiles them here -- shaped to satisfy
    the checks in ``FLARE._evaluate``: non-empty formulations, a
    ``MILPReformulation`` definition, zero compile exits, and a proof depending
    only on the standard axioms.
    """
    (wd / "A" / "Formulation.lean").write_text(_FORMULATION_LEAN)
    (wd / "B" / "Formulation.lean").write_text(_FORMULATION_LEAN)
    (wd / "Reformulation.lean").write_text(_REFORMULATION_LEAN)
    (wd / "result.json").write_text(
        json.dumps(
            {"form_a_compile_exit": 0, "form_b_compile_exit": 0, "compile_exit": 0}
        )
    )
    (wd / "compile_log.txt").write_text(_COMPILE_LOG)


@pytest.fixture
def fake_agent(monkeypatch: pytest.MonkeyPatch) -> None:
    """Run the agent in-process: no Docker, no credentials, no model call."""

    for name in _PLACEHOLDER_ENV:
        monkeypatch.setenv(name, "test-placeholder")

    def start(self: DockerRunner, wd: Path, auth: AuthSpec) -> AgentRun:
        _write_agent_outputs(wd)
        return _FakeAgentRun()

    monkeypatch.setattr(DockerRunner, "start", start)


@pytest.fixture(autouse=True)
def _doctest_sandbox(
    request: pytest.FixtureRequest, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Give every docstring example a fake agent and a scratch working dir."""
    if not isinstance(request.node, pytest.DoctestItem):
        return
    request.getfixturevalue("fake_agent")
    monkeypatch.chdir(tmp_path)
