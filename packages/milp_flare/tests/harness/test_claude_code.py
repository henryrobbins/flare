"""Unit tests for the Claude Code harness — Docker-independent logic.

Covers JSONL stream parsing, working-directory setup, and the credential
forwarding contract. `test_docker.py` remains the behavioral source of
truth; assertions on the wd / docker-args contract are deliberately loose.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from milp_flare._assets import SKILLS_DIR
from milp_flare.harness.claude_code import ClaudeCodeHarness


def _claude() -> ClaudeCodeHarness:
    return ClaudeCodeHarness(model="claude-opus-4-7")


def _skill_dirs(d: Path) -> set[str]:
    """Names of the skill sub-directories under `d`."""
    return {p.name for p in d.iterdir() if p.is_dir()}


# ---------------------------------------------------------------------------
# stream parsing
# ---------------------------------------------------------------------------


def test_parse_result_event() -> None:
    """A `result` event yields tokens, cost, and stop reason."""
    lines = [
        json.dumps({"type": "system", "subtype": "init"}),
        json.dumps(
            {
                "type": "result",
                "stop_reason": "end_turn",
                "total_cost_usd": 0.1234,
                "usage": {"input_tokens": 1500, "output_tokens": 320},
            }
        ),
    ]
    assert _claude()._parse_lines(lines) == {
        "stop_reason": "end_turn",
        "input_tokens": 1500,
        "output_tokens": 320,
        "cost_usd": 0.1234,
    }


def test_parse_last_result_wins() -> None:
    """When multiple `result` events appear, the last one is reported."""
    lines = [
        json.dumps(
            {
                "type": "result",
                "stop_reason": "max_tokens",
                "total_cost_usd": 0.01,
                "usage": {"input_tokens": 1, "output_tokens": 2},
            }
        ),
        json.dumps(
            {
                "type": "result",
                "stop_reason": "end_turn",
                "total_cost_usd": 0.02,
                "usage": {"input_tokens": 10, "output_tokens": 20},
            }
        ),
    ]
    parsed = _claude()._parse_lines(lines)
    assert parsed["stop_reason"] == "end_turn"
    assert parsed["input_tokens"] == 10
    assert parsed["output_tokens"] == 20
    assert parsed["cost_usd"] == 0.02


def test_parse_result_without_usage() -> None:
    """A `result` event missing `usage` leaves token counts at zero."""
    lines = [json.dumps({"type": "result", "stop_reason": "end_turn"})]
    parsed = _claude()._parse_lines(lines)
    assert parsed["input_tokens"] == 0
    assert parsed["output_tokens"] == 0
    assert parsed["cost_usd"] is None


def test_parse_no_result_and_skips_junk() -> None:
    """Blank lines, non-JSON, and non-result events fall back to defaults."""
    lines = ["", "   ", "not json", json.dumps({"type": "assistant"})]
    assert _claude()._parse_lines(lines) == {
        "stop_reason": None,
        "input_tokens": 0,
        "output_tokens": 0,
        "cost_usd": None,
    }


# ---------------------------------------------------------------------------
# configure_wd
# ---------------------------------------------------------------------------


def test_configure_wd(tmp_path: Path) -> None:
    """agent.sh, .mcp.json, and skills are placed under .claude/skills."""
    harness = _claude()
    harness.configure_wd(tmp_path)

    assert (tmp_path / "agent.sh").exists()
    assert (tmp_path / ".mcp.json").exists()
    assert _skill_dirs(tmp_path / ".claude" / "skills") == _skill_dirs(SKILLS_DIR)


def test_configure_wd_is_idempotent(tmp_path: Path) -> None:
    """Re-running configure_wd over a populated wd does not error."""
    harness = _claude()
    harness.configure_wd(tmp_path)
    harness.configure_wd(tmp_path)  # exercises exist_ok / dirs_exist_ok paths
    assert _skill_dirs(tmp_path / ".claude" / "skills") == _skill_dirs(SKILLS_DIR)


# ---------------------------------------------------------------------------
# auth_spec — credential forwarding contract
# ---------------------------------------------------------------------------


def test_auth_spec_requires_oauth_token(monkeypatch: pytest.MonkeyPatch) -> None:
    """Claude Code raises a helpful error when the OAuth token is unset."""
    monkeypatch.delenv("CLAUDE_CODE_OAUTH_TOKEN", raising=False)
    with pytest.raises(RuntimeError, match="CLAUDE_CODE_OAUTH_TOKEN"):
        _claude().auth_spec()


def test_auth_spec_forwards_oauth_token(monkeypatch: pytest.MonkeyPatch) -> None:
    """When set, the OAuth token is forwarded as an env var (no home dirs)."""
    monkeypatch.setenv("CLAUDE_CODE_OAUTH_TOKEN", "secret")
    spec = _claude().auth_spec()
    assert "CLAUDE_CODE_OAUTH_TOKEN" in spec.env
    assert spec.home_dirs == []
