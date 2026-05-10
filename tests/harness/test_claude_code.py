"""Integration tests for ClaudeCodeHarness."""

from __future__ import annotations

import json
import shutil
from collections.abc import Callable
from pathlib import Path

import pytest

from src.llm_client import LLMConfig
from src.verify.flare.flare import setup_lean_project
from src.verify.flare.harness.claude_code import ClaudeCodeHarness


def load_events(jsonl_path: Path) -> list[dict]:
    events: list[dict] = []
    for raw in jsonl_path.read_text().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            events.append(json.loads(raw))
        except json.JSONDecodeError:
            continue
    return events


def classify(
    events: list[dict],
    tool_name: str,
    tool_input_matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    """Classify the first matching tool_use as success | blocked | missing.

    `tool_input_matches` is a predicate over the tool_use `input` dict;
    it picks which invocation the test cares about when the agent could
    plausibly call `tool_name` more than once. Default accepts any.

    `blocked` covers both permission-allowlist denials (which surface in
    the final `result.permission_denials` array) and OS-sandbox / runtime
    errors (which surface as a `tool_result` with `is_error: true`).
    """
    target_id: str | None = None
    for ev in events:
        if ev.get("type") != "assistant":
            continue
        for c in ev.get("message", {}).get("content", []) or []:
            if (
                c.get("type") == "tool_use"
                and c.get("name") == tool_name
                and tool_input_matches(c.get("input") or {})
            ):
                target_id = c.get("id")
                break
        if target_id is not None:
            break

    if target_id is None:
        return "missing", "no matching tool_use in stream"

    for ev in events:
        if ev.get("type") != "result":
            continue
        for d in ev.get("permission_denials") or []:
            if d.get("tool_use_id") == target_id:
                return "blocked", "permission_denials (allowlist)"

    for ev in events:
        if ev.get("type") != "user":
            continue
        for c in ev.get("message", {}).get("content", []) or []:
            if c.get("type") == "tool_result" and c.get("tool_use_id") == target_id:
                if c.get("is_error"):
                    content = c.get("content")
                    return "blocked", f"tool_result is_error: {content!r}"
                return "success", "tool_result ok"

    return "missing", f"tool_use_id {target_id} has no tool_result"


pytestmark = pytest.mark.harness

ONE_CALL_PROMPT = """\
You are testing harness permissions. Make exactly one tool call and then
stop.

The single tool call you must make: {action}

Rules:
- Make this exact tool call once. Do not retry on failure.
- Do not use any other tool. If the call fails, just stop.
- Do not write any files. Do not summarize. Just make the one call.
"""


@pytest.fixture
def harness(test_model: str, test_effort: str) -> ClaudeCodeHarness:
    cfg = LLMConfig(
        model=test_model,
        max_tokens=4096,
        reasoning=False,
        reasoning_effort=test_effort,
    )
    return ClaudeCodeHarness(cfg)


def _make_wd(repo_root: Path, case_id: str, *, lean: bool = False) -> Path:
    """Create a fresh per-test working directory under tests/.runs/.

    With `lean=True`, provision the Lean project (mirrors FLAREVerifier).
    """
    run_dir = repo_root / "tests" / ".runs" / "claude_code" / case_id
    if run_dir.exists():
        shutil.rmtree(run_dir)
    run_dir.mkdir(parents=True)
    wd = run_dir / "wd"
    if lean:
        setup_lean_project(wd, repo_root)
    else:
        wd.mkdir()
    return wd


def _run(
    harness: ClaudeCodeHarness,
    repo_root: Path,
    wd: Path,
    action: str,
) -> Path:
    harness.configure_wd(wd, repo_root)
    jsonl_path = wd.parent / "stream.jsonl"
    harness.run(ONE_CALL_PROMPT.format(action=action), wd, jsonl_path)
    return jsonl_path


def _assert_outcome(
    jsonl_path: Path,
    tool_name: str,
    tool_input_matches: Callable[[dict], bool],
    expected: str,
) -> None:
    events = load_events(jsonl_path)
    outcome, evidence = classify(events, tool_name, tool_input_matches)
    assert outcome != "missing", (
        f"agent did not invoke {tool_name} with matching input "
        f"({evidence}). jsonl={jsonl_path}"
    )
    assert outcome == expected, (
        f"expected `{expected}`, got `{outcome}` ({evidence}). " f"jsonl={jsonl_path}"
    )


def test_read_inside_wd(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """Read of a file inside the wd succeeds."""
    wd = _make_wd(repo_root, "read_inside_wd")
    (wd / "inside.txt").write_text("hello-from-inside\n")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the Read tool to read the file `./inside.txt` "
        "(relative to your current working directory).",
    )
    _assert_outcome(
        jsonl,
        tool_name="Read",
        tool_input_matches=lambda inp: Path(inp.get("file_path", "")).name
        == "inside.txt",
        expected="success",
    )


def test_read_repo_root_file_blocked(
    harness: ClaudeCodeHarness, repo_root: Path
) -> None:
    """Read outside the wd (repo root) is blocked by the sandbox."""
    wd = _make_wd(repo_root, "read_repo_root_file")
    target = repo_root / "Common.lean"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the Read tool to read the absolute path `{target}`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="Read",
        tool_input_matches=lambda inp: Path(inp.get("file_path", "")).resolve()
        == target.resolve(),
        expected="blocked",
    )


def test_write_inside_wd(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """Write inside the wd succeeds."""
    wd = _make_wd(repo_root, "write_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the Write tool to create the file `./created_by_agent.txt` "
        "(relative to your current working directory) with the contents `ok`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="Write",
        tool_input_matches=lambda inp: inp.get("file_path", "").endswith(
            "created_by_agent.txt"
        ),
        expected="success",
    )


def test_write_repo_root_blocked(
    harness: ClaudeCodeHarness, repo_root: Path
) -> None:
    """Write outside the wd (into repo root) is blocked by the sandbox."""
    wd = _make_wd(repo_root, "write_repo_root")
    target = repo_root / "created_by_agent_outside.txt"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the Write tool to create the file at the absolute path "
        f"`{target}` with the contents `ok`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="Write",
        tool_input_matches=lambda inp: Path(inp.get("file_path", "")).resolve()
        == target.resolve(),
        expected="blocked",
    )
    assert not target.exists(), (
        f"sandbox should have blocked the write, but {target} exists"
    )


def test_bash_ls_inside_wd(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """`ls .` inside the wd succeeds."""
    wd = _make_wd(repo_root, "bash_ls_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the Bash tool to run exactly: `ls .`",
    )
    _assert_outcome(
        jsonl,
        tool_name="Bash",
        tool_input_matches=lambda inp: "ls ." in inp.get("command", ""),
        expected="success",
    )


def test_bash_ls_repo_root_blocked(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """`ls <repo_root>` is blocked (outside the wd)."""
    wd = _make_wd(repo_root, "bash_ls_repo_root")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the Bash tool to run exactly: `ls {repo_root}`",
    )
    _assert_outcome(
        jsonl,
        tool_name="Bash",
        tool_input_matches=lambda inp: f"ls {repo_root}" in inp.get("command", ""),
        expected="blocked",
    )


def test_skill_invocable(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """Agent invokes a skill that `configure_wd` copied into wd/.claude/skills/."""
    wd = _make_wd(repo_root, "skill_invocable", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the Skill tool to invoke the `lean-milp-formulation` skill.",
    )
    _assert_outcome(
        jsonl,
        tool_name="Skill",
        tool_input_matches=lambda inp: "lean-milp-formulation"
        in str(inp.get("skill") or inp.get("name") or inp),
        expected="success",
    )


@pytest.mark.lean
def test_lake_build_common(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """Agent runs `lake build Common` via Bash and it succeeds."""
    wd = _make_wd(repo_root, "lake_build_common", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the Bash tool to run exactly: `lake build Common`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="Bash",
        tool_input_matches=lambda inp: "lake build Common"
        in (inp.get("command") or ""),
        expected="success",
    )


@pytest.mark.lean
def test_lean_lsp_mcp(harness: ClaudeCodeHarness, repo_root: Path) -> None:
    """Agent calls a lean-lsp MCP tool and gets a non-error response."""
    wd = _make_wd(repo_root, "lean_lsp_mcp", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Call the MCP tool `mcp__lean-lsp__lean_diagnostic_messages` on "
        "the file `./Common.lean` (path relative to your current working "
        "directory).",
    )
    _assert_outcome(
        jsonl,
        tool_name="mcp__lean-lsp__lean_diagnostic_messages",
        tool_input_matches=lambda _inp: True,
        expected="success",
    )
