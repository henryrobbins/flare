"""Integration tests for CodexHarness.

Codex's `workspace-write` sandbox restricts *writes* (to `writable_roots`)
and network, but does NOT block reads outside `wd` (see
openai/codex#2847). The two read-outside-wd tests below are xfailed to
document that gap until codex's permissions profile system stabilizes
enough to enforce a deny-read policy under `approval_policy = "never"`.

Codex does not expose distinct Read/Write/Skill tools — the agent uses
shell commands (`command_execution`) and `apply_patch` (`file_change`)
for filesystem ops, plus `mcp_tool_call` for MCP. We classify those
event types instead of Claude's `tool_use`/`tool_result` pairs.
"""

from __future__ import annotations

import json
import shutil
from collections.abc import Callable
from pathlib import Path

import pytest

from src.llm_client import LLMConfig
from src.verify.flare.flare import setup_lean_project
from src.verify.flare.harness.codex import CodexHarness


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
    item_type: str,
    item_matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    """Classify the first matching `item.completed` as success | blocked | missing.

    `item_matches` is a predicate over the `item` dict; it picks which
    invocation the test cares about when the agent could plausibly emit
    more than one item of `item_type`. Default accepts any.

    `blocked` covers both sandbox / permission denials (which surface as
    non-zero exit codes for `command_execution`, `status: "failed"` for
    `file_change`, or an `isError`/error result for `mcp_tool_call`) and
    other runtime errors with the same surface.
    """
    target: dict | None = None
    for ev in events:
        if ev.get("type") != "item.completed":
            continue
        item = ev.get("item") or {}
        if item.get("type") != item_type:
            continue
        if not item_matches(item):
            continue
        target = item
        break

    if target is None:
        return "missing", f"no matching `{item_type}` item.completed in stream"

    if item_type == "command_execution":
        status = target.get("status")
        exit_code = target.get("exit_code")
        if status == "completed" and exit_code == 0:
            return "success", "exit_code 0"
        return "blocked", f"status={status!r} exit_code={exit_code!r}"

    if item_type == "file_change":
        status = target.get("status")
        if status == "completed":
            return "success", "file_change completed"
        return "blocked", f"file_change status={status!r}"

    if item_type == "mcp_tool_call":
        result = target.get("result") or {}
        if result.get("isError") or result.get("is_error"):
            return "blocked", f"mcp result is_error: {result!r}"
        if not result:
            return "blocked", "mcp_tool_call has no result"
        return "success", "mcp_tool_call ok"

    return "missing", f"unknown item_type {item_type}"


pytestmark = pytest.mark.harness

ONE_CALL_PROMPT = """\
You are testing harness permissions. Make exactly one tool call and then
stop.

The single tool call you must make: {action}

Rules:
- Make this exact tool call once. Do not retry on failure.
- Do not use any other tool. If the call fails, just stop.
- Do not summarize. Just make the one call.
"""


@pytest.fixture
def harness() -> CodexHarness:
    cfg = LLMConfig(
        model="gpt-5.4",
        max_tokens=4096,
        reasoning=False,
        reasoning_effort="low",
    )
    return CodexHarness(cfg)


def _make_wd(repo_root: Path, case_id: str, *, lean: bool = False) -> Path:
    """Create a fresh per-test working directory under tests/.runs/.

    With `lean=True`, provision the Lean project (mirrors FLAREVerifier).
    """
    run_dir = repo_root / "tests" / ".runs" / "codex" / case_id
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
    harness: CodexHarness,
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
    item_type: str,
    item_matches: Callable[[dict], bool],
    expected: str,
) -> None:
    events = load_events(jsonl_path)
    outcome, evidence = classify(events, item_type, item_matches)
    assert outcome != "missing", (
        f"agent did not emit `{item_type}` matching predicate "
        f"({evidence}). jsonl={jsonl_path}"
    )
    assert outcome == expected, (
        f"expected `{expected}`, got `{outcome}` ({evidence}). jsonl={jsonl_path}"
    )


def test_read_inside_wd(harness: CodexHarness, repo_root: Path) -> None:
    """`cat` of a file inside the wd succeeds."""
    wd = _make_wd(repo_root, "read_inside_wd")
    (wd / "inside.txt").write_text("hello-from-inside\n")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Run exactly: `cat ./inside.txt` (relative to your current "
        "working directory).",
    )
    _assert_outcome(
        jsonl,
        item_type="command_execution",
        item_matches=lambda it: "cat ./inside.txt" in (it.get("command") or ""),
        expected="success",
    )


@pytest.mark.xfail(
    reason="codex 0.130 workspace-write does not block reads; see openai/codex#2847",
    strict=True,
)
def test_read_repo_root_file_blocked(
    harness: CodexHarness, repo_root: Path
) -> None:
    """Read outside the wd should be blocked (currently isn't — see xfail)."""
    wd = _make_wd(repo_root, "read_repo_root_file")
    target = repo_root / "Common.lean"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Run exactly: `cat {target}`.",
    )
    _assert_outcome(
        jsonl,
        item_type="command_execution",
        item_matches=lambda it: f"cat {target}" in (it.get("command") or ""),
        expected="blocked",
    )


def test_write_inside_wd(harness: CodexHarness, repo_root: Path) -> None:
    """Write inside the wd succeeds."""
    wd = _make_wd(repo_root, "write_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Create the file `./created_by_agent.txt` (relative to your "
        "current working directory) with the contents `ok`.",
    )
    _assert_outcome(
        jsonl,
        item_type="file_change",
        item_matches=lambda it: any(
            str(c.get("path", "")).endswith("created_by_agent.txt")
            for c in (it.get("changes") or [])
        ),
        expected="success",
    )


def test_write_repo_root_blocked(
    harness: CodexHarness, repo_root: Path
) -> None:
    """Write outside the wd (into repo root) is blocked by the sandbox.

    Codex may either emit a `file_change` with `status: "failed"` or
    decline outright (no `file_change` at all); both satisfy the security
    goal as long as the target file does not appear on disk and no
    `file_change` for the target reports `status: "completed"`.
    """
    wd = _make_wd(repo_root, "write_repo_root")
    target = repo_root / "created_by_agent_outside.txt"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Create the file at the absolute path `{target}` with the "
        f"contents `ok`.",
    )

    events = load_events(jsonl)
    completed_writes = [
        ev for ev in events
        if ev.get("type") == "item.completed"
        and (it := ev.get("item") or {}).get("type") == "file_change"
        and it.get("status") == "completed"
        and any(
            Path(c.get("path", "")).resolve() == target.resolve()
            for c in (it.get("changes") or [])
        )
    ]
    assert not completed_writes, (
        f"sandbox should have blocked the write, but a file_change "
        f"completed for {target}. jsonl={jsonl}"
    )
    assert not target.exists(), (
        f"sandbox should have blocked the write, but {target} exists"
    )


def test_bash_ls_inside_wd(harness: CodexHarness, repo_root: Path) -> None:
    """`ls .` inside the wd succeeds."""
    wd = _make_wd(repo_root, "bash_ls_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Run exactly: `ls .`",
    )
    _assert_outcome(
        jsonl,
        item_type="command_execution",
        item_matches=lambda it: "ls ." in (it.get("command") or ""),
        expected="success",
    )


@pytest.mark.xfail(
    reason="codex 0.130 workspace-write does not block reads; see openai/codex#2847",
    strict=True,
)
def test_bash_ls_repo_root_blocked(
    harness: CodexHarness, repo_root: Path
) -> None:
    """`ls <repo_root>` should be blocked (currently isn't — see xfail)."""
    wd = _make_wd(repo_root, "bash_ls_repo_root")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Run exactly: `ls {repo_root}`",
    )
    _assert_outcome(
        jsonl,
        item_type="command_execution",
        item_matches=lambda it: f"ls {repo_root}" in (it.get("command") or ""),
        expected="blocked",
    )


def test_skill_copied(harness: CodexHarness, repo_root: Path) -> None:
    """`configure_wd` copies skills into wd/.agents/skills/ (Codex's path).

    Codex has no `Skill` tool the way Claude Code does, so we verify the
    skill file is on disk where Codex would discover it, rather than
    asking the agent to invoke it.
    """
    wd = _make_wd(repo_root, "skill_copied", lean=True)
    harness.configure_wd(wd, repo_root)

    skill_dir = wd / ".agents" / "skills" / "lean-milp-formulation"
    assert skill_dir.exists(), f"expected skill copied to {skill_dir}"


@pytest.mark.lean
def test_lake_build_common(harness: CodexHarness, repo_root: Path) -> None:
    """Agent runs `lake build Common` via shell and it succeeds.

    Use a bespoke prompt rather than `ONE_CALL_PROMPT` because lake
    build can run for several seconds, and gpt-5 at low effort tends
    to end the turn before the command completes when told "do not
    summarize, just make the one call". We instruct it explicitly to
    wait for completion.
    """
    wd = _make_wd(repo_root, "lake_build_common", lean=True)

    harness.configure_wd(wd, repo_root)
    jsonl_path = wd.parent / "stream.jsonl"
    harness.run(
        "Run exactly the shell command `lake build Common` and wait "
        "for it to finish before ending your turn. Do not run any "
        "other command.",
        wd,
        jsonl_path,
    )

    _assert_outcome(
        jsonl_path,
        item_type="command_execution",
        item_matches=lambda it: "lake build Common" in (it.get("command") or ""),
        expected="success",
    )


@pytest.mark.lean
def test_lean_lsp_mcp(harness: CodexHarness, repo_root: Path) -> None:
    """Agent calls a lean-lsp MCP tool and gets a non-error response."""
    wd = _make_wd(repo_root, "lean_lsp_mcp", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Call the MCP tool `lean_diagnostic_messages` on the lean-lsp "
        "server with the file `./Common.lean` (path relative to your "
        "current working directory).",
    )
    _assert_outcome(
        jsonl,
        item_type="mcp_tool_call",
        item_matches=lambda it: it.get("server") == "lean-lsp"
        and it.get("tool") == "lean_diagnostic_messages",
        expected="success",
    )
