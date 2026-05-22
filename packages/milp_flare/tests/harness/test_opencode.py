"""Unit tests for the OpenCode harness — Docker-independent logic.

Covers JSONL stream parsing, working-directory setup, and the credential
forwarding contract. `test_docker.py` remains the behavioral source of
truth; assertions on the wd / docker-args contract are deliberately loose.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from milp_flare._assets import SKILLS_DIR
from milp_flare.harness.opencode import OpenCodeHarness

_OPENCODE_KEYS = (
    "ANTHROPIC_API_KEY",
    "OPENAI_API_KEY",
    "GOOGLE_API_KEY",
    "DEEPSEEK_API_KEY",
)


def _opencode() -> OpenCodeHarness:
    return OpenCodeHarness(model="deepseek-v4-pro")


def _skill_dirs(d: Path) -> set[str]:
    """Names of the skill sub-directories under `d`."""
    return {p.name for p in d.iterdir() if p.is_dir()}


# ---------------------------------------------------------------------------
# stream parsing
# ---------------------------------------------------------------------------


def test_parse_step_finish() -> None:
    """Input tokens fold in cache read/write; cost and reason are reported."""
    lines = [
        json.dumps(
            {
                "type": "step_finish",
                "part": {
                    "tokens": {
                        "input": 100,
                        "output": 40,
                        "cache": {"write": 5, "read": 7},
                    },
                    "cost": 0.05,
                    "reason": "stop",
                },
            }
        )
    ]
    assert _opencode()._parse_lines(lines) == {
        "stop_reason": "stop",
        "input_tokens": 112,
        "output_tokens": 40,
        "cost_usd": 0.05,
    }


def test_parse_accumulates_steps() -> None:
    """Tokens and cost accumulate across multiple `step_finish` events."""

    def step(cost: float) -> str:
        return json.dumps(
            {
                "type": "step_finish",
                "part": {
                    "tokens": {"input": 10, "output": 2},
                    "cost": cost,
                    "reason": "stop",
                },
            }
        )

    parsed = _opencode()._parse_lines([step(0.01), step(0.02)])
    assert parsed["input_tokens"] == 20
    assert parsed["output_tokens"] == 4
    assert parsed["cost_usd"] == pytest.approx(0.03)


def test_parse_handles_missing_and_non_int() -> None:
    """Non-int token values become zero; junk and other events are skipped."""
    lines = [
        "",
        "junk",
        json.dumps({"type": "tool_use"}),
        json.dumps(
            {"type": "step_finish", "part": {"tokens": {"input": None, "output": "x"}}}
        ),
    ]
    assert _opencode()._parse_lines(lines) == {
        "stop_reason": None,
        "input_tokens": 0,
        "output_tokens": 0,
        "cost_usd": None,
    }


# ---------------------------------------------------------------------------
# configure_wd
# ---------------------------------------------------------------------------


def test_configure_wd(tmp_path: Path) -> None:
    """agent.sh, opencode.json, and skills are placed under .agents/skills."""
    _opencode().configure_wd(tmp_path)

    assert (tmp_path / "agent.sh").exists()
    assert _skill_dirs(tmp_path / ".agents" / "skills") == _skill_dirs(SKILLS_DIR)

    config = json.loads((tmp_path / "opencode.json").read_text())
    assert "deepseek" in config["provider"]
    assert "lean-lsp" in config["mcp"]


# ---------------------------------------------------------------------------
# _agent_docker_args — credential forwarding contract
# ---------------------------------------------------------------------------


def test_docker_args_forwards_only_set_keys(monkeypatch: pytest.MonkeyPatch) -> None:
    """OpenCode forwards exactly the provider API keys that are set."""
    for key in _OPENCODE_KEYS:
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "a")
    monkeypatch.setenv("DEEPSEEK_API_KEY", "d")

    args = _opencode()._agent_docker_args()

    assert "ANTHROPIC_API_KEY" in args
    assert "DEEPSEEK_API_KEY" in args
    assert "OPENAI_API_KEY" not in args
    assert "GOOGLE_API_KEY" not in args


def test_docker_args_empty_when_no_keys(monkeypatch: pytest.MonkeyPatch) -> None:
    """OpenCode forwards nothing (and does not raise) when no keys are set."""
    for key in _OPENCODE_KEYS:
        monkeypatch.delenv(key, raising=False)
    assert _opencode()._agent_docker_args() == []
