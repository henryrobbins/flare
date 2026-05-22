"""Unit tests for the Codex harness — Docker-independent logic.

Covers JSONL stream parsing, working-directory setup, and the credential
forwarding contract. `test_docker.py` remains the behavioral source of
truth; assertions on the wd / docker-args contract are deliberately loose.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from milp_flare._assets import SKILLS_DIR
from milp_flare.harness import codex as codex_module
from milp_flare.harness.codex import CodexHarness


def _codex() -> CodexHarness:
    return CodexHarness(model="gpt-5.5")


def _skill_dirs(d: Path) -> set[str]:
    """Names of the skill sub-directories under `d`."""
    return {p.name for p in d.iterdir() if p.is_dir()}


# ---------------------------------------------------------------------------
# stream parsing
# ---------------------------------------------------------------------------


def test_parse_turn_completed() -> None:
    """A `turn.completed` event yields tokens and stop reason; cost is None."""
    lines = [
        json.dumps(
            {
                "type": "turn.completed",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 800, "output_tokens": 120},
            }
        )
    ]
    assert _codex()._parse_lines(lines) == {
        "stop_reason": "end_turn",
        "input_tokens": 800,
        "output_tokens": 120,
        "cost_usd": None,
    }


def test_parse_accumulates_and_alt_keys() -> None:
    """Tokens accumulate across turns; camelCase / prompt_tokens keys work."""
    lines = [
        json.dumps(
            {
                "type": "turn.completed",
                "usage": {"inputTokens": 100, "outputTokens": 10},
            }
        ),
        json.dumps(
            {
                "type": "turn.completed",
                "finish_reason": "stop",
                "usage": {"prompt_tokens": 200, "completion_tokens": 20},
            }
        ),
    ]
    parsed = _codex()._parse_lines(lines)
    assert parsed["input_tokens"] == 300
    assert parsed["output_tokens"] == 30
    assert parsed["stop_reason"] == "stop"
    assert parsed["cost_usd"] is None


def test_parse_non_int_tokens_ignored() -> None:
    """Non-integer token values are dropped rather than crashing."""
    lines = [
        json.dumps(
            {
                "type": "turn.completed",
                "usage": {"input_tokens": "lots", "output_tokens": 5},
            }
        )
    ]
    parsed = _codex()._parse_lines(lines)
    assert parsed["input_tokens"] == 0
    assert parsed["output_tokens"] == 5


def test_parse_ignores_other_events() -> None:
    """Blank lines, non-JSON, and non-turn events leave defaults intact."""
    lines = [
        "",
        "junk",
        json.dumps({"type": "item.completed"}),
        json.dumps({"type": "turn.completed"}),  # no usage
    ]
    assert _codex()._parse_lines(lines) == {
        "stop_reason": None,
        "input_tokens": 0,
        "output_tokens": 0,
        "cost_usd": None,
    }


# ---------------------------------------------------------------------------
# configure_wd
# ---------------------------------------------------------------------------


def test_configure_wd(tmp_path: Path) -> None:
    """agent.sh and skills are copied under .agents/skills."""
    _codex().configure_wd(tmp_path)

    assert (tmp_path / "agent.sh").exists()
    assert _skill_dirs(tmp_path / ".agents" / "skills") == _skill_dirs(SKILLS_DIR)


# ---------------------------------------------------------------------------
# _agent_docker_args — credential forwarding contract
# ---------------------------------------------------------------------------


def test_docker_args_requires_codex_login(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Codex raises a helpful error when ~/.codex is absent."""
    monkeypatch.setattr(codex_module.Path, "home", lambda: tmp_path)
    with pytest.raises(RuntimeError, match="codex"):
        _codex()._agent_docker_args()


def test_docker_args_mounts_codex_dir(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """When ~/.codex exists, it is bind-mounted into the container."""
    (tmp_path / ".codex").mkdir()
    monkeypatch.setattr(codex_module.Path, "home", lambda: tmp_path)
    args = _codex()._agent_docker_args()
    # the host ~/.codex appears in one of the bind-mount specs
    assert any(str(tmp_path / ".codex") in a for a in args)
