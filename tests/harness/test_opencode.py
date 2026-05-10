"""Integration tests for OpenCodeHarness.

OpenCode has no OS-level sandbox: the filesystem confinement that Claude
Code gets from `sandbox` and Codex gets from `default_permissions` comes
from path-pattern allowlists in `opencode.json`. Reads/edits/globs/greps
outside the wd are denied via per-permission path globs; bash is denied
by default and re-allowed for a small set of commands (`lake build *`,
`ls *`, `cat *`, ...). So OpenCode's `tool_use` events surface
`status: "error"` with a `state.error` message that quotes the rule that
denied the call, instead of an OS sandbox error.

OpenCode emits one JSON event per line (`opencode run --format json`).
The events that matter here are `tool_use`, with this shape::

    {"type": "tool_use",
     "part": {"type": "tool",
              "tool": "<bash|read|write|edit|skill|lean-lsp_...>",
              "state": {"status": "completed" | "error",
                        "input": {...},
                        "output": "...",          # completed only
                        "metadata": {"exit": N},  # bash, completed only
                        "error": "..."}}}        # error only

Tool inputs are tool-specific: `read`/`write` use `filePath`; `bash` uses
`command`; `skill` uses `name`; the lean-lsp MCP server fuses its name
into the tool, e.g. `lean-lsp_lean_diagnostic_messages`, with input
`{file_path: ...}`.
"""

from __future__ import annotations

import json
import shutil
from collections.abc import Callable
from pathlib import Path

import pytest

from src.llm_client import LLMConfig
from src.verify.flare.flare import setup_lean_project
from src.verify.flare.harness.opencode import OpenCodeHarness


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
    input_matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    """Classify the first matching `tool_use` as success | blocked | missing.

    `input_matches` is a predicate over the tool's `state.input` dict; it
    picks which invocation the test cares about when the agent could
    plausibly call `tool_name` more than once. Default accepts any.

    `blocked` covers both permission denials (`status: "error"` with a
    rule message in `state.error`) and bash commands that ran but exited
    non-zero (`status: "completed"`, `state.metadata.exit != 0`).
    """
    target: dict | None = None
    for ev in events:
        if ev.get("type") != "tool_use":
            continue
        part = ev.get("part") or {}
        if part.get("tool") != tool_name:
            continue
        state = part.get("state") or {}
        if not input_matches(state.get("input") or {}):
            continue
        target = state
        break

    if target is None:
        return "missing", f"no matching tool_use for `{tool_name}` in stream"

    status = target.get("status")
    if status == "error":
        return "blocked", f"state.error: {target.get('error')!r}"
    if status != "completed":
        return "blocked", f"status={status!r}"

    if tool_name == "bash":
        exit_code = (target.get("metadata") or {}).get("exit")
        if exit_code != 0:
            return "blocked", f"exit_code={exit_code!r}"

    return "success", f"status={status!r}"


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
def harness() -> OpenCodeHarness:
    cfg = LLMConfig(
        model="claude-haiku-4-5",
        max_tokens=4096,
        reasoning=False,
        reasoning_effort="low",
    )
    return OpenCodeHarness(cfg)


def _make_wd(repo_root: Path, case_id: str, *, lean: bool = False) -> Path:
    """Create a fresh per-test working directory under tests/.runs/.

    With `lean=True`, provision the Lean project (mirrors FLAREVerifier).
    """
    run_dir = repo_root / "tests" / ".runs" / "opencode" / case_id
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
    harness: OpenCodeHarness,
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
    input_matches: Callable[[dict], bool],
    expected: str,
) -> None:
    events = load_events(jsonl_path)
    outcome, evidence = classify(events, tool_name, input_matches)
    assert outcome != "missing", (
        f"agent did not invoke `{tool_name}` with matching input "
        f"({evidence}). jsonl={jsonl_path}"
    )
    assert outcome == expected, (
        f"expected `{expected}`, got `{outcome}` ({evidence}). jsonl={jsonl_path}"
    )


def test_read_inside_wd(harness: OpenCodeHarness, repo_root: Path) -> None:
    """Read of a file inside the wd succeeds."""
    wd = _make_wd(repo_root, "read_inside_wd")
    target = wd / "inside.txt"
    target.write_text("hello-from-inside\n")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the read tool on the absolute path `{target}`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="read",
        input_matches=lambda inp: Path(inp.get("filePath", "")).name == "inside.txt",
        expected="success",
    )


def test_read_repo_root_file_blocked(
    harness: OpenCodeHarness, repo_root: Path
) -> None:
    """Read outside the wd is blocked by the read-path allowlist."""
    wd = _make_wd(repo_root, "read_repo_root_file")
    target = repo_root / "Common.lean"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the read tool on the absolute path `{target}`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="read",
        input_matches=lambda inp: Path(inp.get("filePath", "")).resolve()
        == target.resolve(),
        expected="blocked",
    )


def test_write_inside_wd(harness: OpenCodeHarness, repo_root: Path) -> None:
    """Write inside the wd succeeds."""
    wd = _make_wd(repo_root, "write_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the write tool to create the file "
        "`./created_by_agent.txt` (relative to your current working "
        "directory) with the contents `ok`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="write",
        input_matches=lambda inp: str(inp.get("filePath", "")).endswith(
            "created_by_agent.txt"
        ),
        expected="success",
    )


@pytest.mark.xfail(
    reason="Upstream OpenCode bug: `edit: { '*': 'deny', '<wd>/**': "
    "'allow' }` denies inside-wd writes too (the same allow rule does "
    "work for `read`). https://github.com/anomalyco/opencode/issues/13872. "
    "Likely related to https://github.com/anomalyco/opencode/issues/26524 "
    "(edit/write/patch use worktree-relative paths but our pattern is "
    "absolute). To keep the agent able to write its working files we "
    "set `edit: { '**': 'allow' }` in the template, so writes outside "
    "the wd are no longer blocked. Reads outside the wd are still "
    "confined via the working `read` allowlist.",
    strict=True,
)
def test_write_repo_root_blocked(
    harness: OpenCodeHarness, repo_root: Path
) -> None:
    """Write outside the wd should be blocked by an edit-path allowlist."""
    wd = _make_wd(repo_root, "write_repo_root")
    # Target is the per-run dir's sibling — outside the wd from the
    # agent's perspective but contained under tests/.runs/ so a write
    # that slips through doesn't pollute the repo.
    target = wd.parent / "created_by_agent_outside.txt"

    jsonl = _run(
        harness,
        repo_root,
        wd,
        f"Use the write tool to create the file at the absolute path "
        f"`{target}` with the contents `ok`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="write",
        input_matches=lambda inp: Path(inp.get("filePath", "")).resolve()
        == target.resolve(),
        expected="blocked",
    )
    assert not target.exists(), (
        f"permissions should have blocked the write, but {target} exists"
    )


def test_bash_ls_inside_wd(harness: OpenCodeHarness, repo_root: Path) -> None:
    """`ls .` is on the bash allowlist and runs successfully."""
    wd = _make_wd(repo_root, "bash_ls_inside_wd")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the bash tool to run exactly: `ls .`",
    )
    _assert_outcome(
        jsonl,
        tool_name="bash",
        input_matches=lambda inp: "ls ." in str(inp.get("command", "")),
        expected="success",
    )


def test_bash_unallowed_command_blocked(
    harness: OpenCodeHarness, repo_root: Path
) -> None:
    """A command not on the bash allowlist (e.g., `whoami`) is blocked.

    OpenCode has no OS sandbox, so to test bash confinement we need a
    command outside the allowlist (`ls`/`cat`/`lake`/...). `whoami` is
    a safe choice that doesn't touch the filesystem.
    """
    wd = _make_wd(repo_root, "bash_unallowed_command")

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the bash tool to run exactly: `whoami`",
    )
    _assert_outcome(
        jsonl,
        tool_name="bash",
        input_matches=lambda inp: "whoami" in str(inp.get("command", "")),
        expected="blocked",
    )


def test_skill_invocable(harness: OpenCodeHarness, repo_root: Path) -> None:
    """Agent invokes a skill that `configure_wd` copied into wd/.claude/skills/.

    OpenCode discovers skills directly from `.claude/skills/` (no rename)
    and the `skill` permission allowlist in `opencode.json` lets the
    agent invoke `lean-milp-formulation`.
    """
    wd = _make_wd(repo_root, "skill_invocable", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the skill tool to invoke the `lean-milp-formulation` skill.",
    )
    _assert_outcome(
        jsonl,
        tool_name="skill",
        input_matches=lambda inp: "lean-milp-formulation"
        in str(inp.get("name") or inp),
        expected="success",
    )


@pytest.mark.lean
def test_lake_build_common(harness: OpenCodeHarness, repo_root: Path) -> None:
    """Agent runs `lake build Common` via bash and it succeeds."""
    wd = _make_wd(repo_root, "lake_build_common", lean=True)

    jsonl = _run(
        harness,
        repo_root,
        wd,
        "Use the bash tool to run exactly: `lake build Common`.",
    )
    _assert_outcome(
        jsonl,
        tool_name="bash",
        input_matches=lambda inp: "lake build Common" in str(inp.get("command", "")),
        expected="success",
    )


@pytest.mark.lean
def test_lean_lsp_mcp(harness: OpenCodeHarness, repo_root: Path) -> None:
    """Agent calls a lean-lsp MCP tool and gets a non-error response.

    OpenCode flattens MCP tool names as `<server>_<tool>`, so the
    lean-lsp `lean_diagnostic_messages` tool surfaces as
    `lean-lsp_lean_diagnostic_messages` in the stream.
    """
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
        tool_name="lean-lsp_lean_diagnostic_messages",
        input_matches=lambda _inp: True,
        expected="success",
    )
