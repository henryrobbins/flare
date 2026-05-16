"""Integration tests for the docker Harness across all three CLIs.

These tests make real model calls inside the Docker image. They are marked
`docker` and excluded by `pytest -m 'not docker'`.

Prerequisites:
  - docker daemon running
  - `milp-flare build-image` has been run (builds `flare-agent:latest`)
  - CLAUDE_CODE_OAUTH_TOKEN in env for claude_code
  - OPENAI_API_KEY in env (or ~/.codex/auth.json on host) for codex
  - DEEPSEEK_API_KEY in env for opencode (tests use deepseek-chat to
    avoid burning Anthropic spend on integration runs)
"""

from __future__ import annotations

import json
import os
import shutil
from collections.abc import Callable
from pathlib import Path

import pytest

from milp_flare import HARNESSES, Harness, LLMConfig
from milp_flare.assets import LEAN_DIR

pytestmark = pytest.mark.docker

ONE_CALL_PROMPT = """\
You are testing a harness. Make exactly one tool call and then stop.

The single tool call you must make: {action}

Rules:
- Make this exact tool call once. Do not retry on failure.
- Do not use any other tool. If the call fails, just stop.
- Do not write any files. Do not summarize. Just make the one call.
"""

CLIS = ["claude_code", "codex", "opencode"]


def _cli_available(cli: str) -> bool:
    if cli == "claude_code":
        return bool(os.environ.get("CLAUDE_CODE_OAUTH_TOKEN"))
    if cli == "codex":
        # Tests bill against the ChatGPT subscription via cached OAuth.
        return (Path.home() / ".codex" / "auth.json").exists()
    if cli == "opencode":
        return bool(os.environ.get("DEEPSEEK_API_KEY"))
    return False


def _model_for(cli: str) -> str:
    if cli == "claude_code":
        return "claude-haiku-4-5"
    if cli == "codex":
        # ChatGPT-subscription auth (the path the tests use) only accepts the
        # codex defaults; gpt-5-mini is API-key-only and 400s on first turn.
        return "gpt-5.5"
    if cli == "opencode":
        # deepseek-chat keeps test cost low and exercises the non-anthropic
        # branch of OpenCode's model-options translation.
        return "deepseek-chat"
    raise AssertionError(cli)


def _harness(cli: str) -> Harness:
    cfg = LLMConfig(
        model=_model_for(cli),
        max_tokens=4096,
        reasoning=False,
        reasoning_effort="low",
    )
    return HARNESSES[cli](config=cfg)


def _make_pair_dir(repo_root: Path, case_id: str) -> Path:
    """Materialize a pair_dir with the Lake skeleton.

    Lake skeleton files would be copied into each wd by FLAREVerifier._setup_wd
    at runtime (see milp_flare/flare.py). These tests bypass FLAREVerifier and
    drive Harness directly, so they have to materialize the same files here —
    otherwise the bind mount of wd onto /workspace would hide the image-side
    skeleton and lake invocations would fail.
    """
    pair_dir = repo_root / "tests" / ".runs" / "docker" / case_id
    if pair_dir.exists():
        shutil.rmtree(pair_dir)
    pair_dir.mkdir(parents=True)
    wd = pair_dir / "wd"
    wd.mkdir()
    for src in LEAN_DIR.iterdir():
        shutil.copy2(src, wd / src.name)
    for label in ("A", "B"):
        (wd / label).mkdir()
        (wd / label / "Formulation.lean").write_text("")
    (wd / "Reformulation.lean").write_text("")
    return pair_dir


def _run(cli: str, repo_root: Path, pair_dir: Path, action: str) -> Path:
    if not _cli_available(cli):
        pytest.skip(f"credentials for {cli} not available")
    harness = _harness(cli)
    wd = pair_dir / "wd"
    harness.configure_wd(wd)
    (wd / "prompt.txt").write_text(ONE_CALL_PROMPT.format(action=action))
    harness.run(wd)
    return wd / "agent_output.jsonl"


def _load_events(jsonl_path: Path) -> list[dict]:
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


# ---- per-CLI classifiers --------------------------------------------------


def _claude_classify(
    events: list[dict],
    tool_name: str,
    matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    target_id: str | None = None
    for ev in events:
        if ev.get("type") != "assistant":
            continue
        for c in ev.get("message", {}).get("content", []) or []:
            if (
                c.get("type") == "tool_use"
                and c.get("name") == tool_name
                and matches(c.get("input") or {})
            ):
                target_id = c.get("id")
                break
        if target_id is not None:
            break
    if target_id is None:
        return "missing", "no matching tool_use"
    for ev in events:
        if ev.get("type") != "user":
            continue
        for c in ev.get("message", {}).get("content", []) or []:
            if c.get("type") == "tool_result" and c.get("tool_use_id") == target_id:
                if c.get("is_error"):
                    return "error", f"tool_result is_error: {c.get('content')!r}"
                return "success", "tool_result ok"
    return "missing", "no tool_result for id"


def _codex_classify(
    events: list[dict],
    item_type: str,
    matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    """Classify codex `item.completed` events.

    Codex does not expose distinct tools; the agent uses `command_execution`
    for shell, `file_change` for edits, `mcp_tool_call` for MCP.
    """
    target: dict | None = None
    for ev in events:
        if ev.get("type") != "item.completed":
            continue
        item = ev.get("item") or {}
        if item.get("type") != item_type or not matches(item):
            continue
        target = item
        break
    if target is None:
        return "missing", f"no matching `{item_type}` in stream"
    if item_type == "command_execution":
        ok = target.get("status") == "completed" and target.get("exit_code") == 0
        return (
            ("success", "exit 0")
            if ok
            else (
                "error",
                f"status={target.get('status')!r} exit={target.get('exit_code')!r}",
            )
        )
    if item_type == "mcp_tool_call":
        result = target.get("result") or {}
        if result.get("isError") or result.get("is_error"):
            return "error", f"mcp is_error: {result!r}"
        return "success", "mcp ok"
    return "missing", f"unhandled item_type {item_type}"


def _opencode_classify(
    events: list[dict],
    tool_name: str,
    matches: Callable[[dict], bool] = lambda _: True,
) -> tuple[str, str]:
    """Classify opencode `tool_use` events.

    OpenCode emits one event per tool call with state.status in {completed,
    error}. bash success additionally requires exit 0.
    """
    target: dict | None = None
    for ev in events:
        if ev.get("type") != "tool_use":
            continue
        part = ev.get("part") or {}
        if part.get("tool") != tool_name:
            continue
        state = part.get("state") or {}
        if not matches(state.get("input") or {}):
            continue
        target = state
        break
    if target is None:
        return "missing", f"no tool_use for `{tool_name}`"
    status = target.get("status")
    if status == "error":
        return "error", f"state.error: {target.get('error')!r}"
    if status != "completed":
        return "error", f"status={status!r}"
    if tool_name == "bash":
        exit_code = (target.get("metadata") or {}).get("exit")
        if exit_code != 0:
            return "error", f"exit={exit_code!r}"
    return "success", f"status={status!r}"


# ---- per-CLI test-action shapes -------------------------------------------


# action template, classifier fn, tool name, matcher predicate factory
def _build_bash_check(cli: str, command: str):
    if cli == "claude_code":
        return (
            f"Use the Bash tool to run exactly: `{command}`.",
            _claude_classify,
            "Bash",
            lambda inp: command in (inp.get("command") or ""),
        )
    if cli == "codex":
        return (
            f"Run exactly this shell command: `{command}`.",
            _codex_classify,
            "command_execution",
            lambda item: command in (item.get("command") or ""),
        )
    if cli == "opencode":
        return (
            f"Use the bash tool to run exactly: `{command}`.",
            _opencode_classify,
            "bash",
            lambda inp: command in (inp.get("command") or ""),
        )
    raise AssertionError(cli)


def _build_skill_check(cli: str, skill_name: str):
    if cli == "claude_code":
        return (
            f"Use the Skill tool to invoke the `{skill_name}` skill.",
            _claude_classify,
            "Skill",
            lambda inp: skill_name in str(inp.get("skill") or inp.get("name") or inp),
        )
    if cli == "opencode":
        return (
            f"Use the skill tool to invoke the `{skill_name}` skill.",
            _opencode_classify,
            "skill",
            lambda inp: skill_name in str(inp.get("name") or inp.get("skill") or inp),
        )
    if cli == "codex":
        # Codex does not expose a distinct "Skill" tool — skills are markdown
        # files at .agents/skills/<name>/SKILL.md that the agent reads on its
        # own. We use a negative behavioral check: the agent must not report
        # the skill missing. If `.agents/skills/<skill>/SKILL.md` is not
        # discoverable, codex emits an agent_message like "skills are not
        # installed" / "not available in this session".
        return (
            f"Look up the `{skill_name}` skill and use it.",
            _codex_skill_classify,
            None,
            None,
        )
    raise AssertionError(cli)


def _codex_skill_classify(
    events: list[dict],
    _tool: str | None,
    _matches,
) -> tuple[str, str]:
    """Pass iff no agent_message reports the skill as missing/unavailable."""
    NEG = (
        "not installed",
        "not available",
        "no skill",
        "skills are not",
        "couldn't find",
        "could not find",
        "cannot find",
    )
    for ev in events:
        if ev.get("type") != "item.completed":
            continue
        item = ev.get("item") or {}
        if item.get("type") != "agent_message":
            continue
        text = (item.get("text") or "").lower()
        for needle in NEG:
            if needle in text:
                return "error", f"agent reported skill missing: {needle!r}"
    return "success", "no skill-missing report in agent_message"


def _build_lean_lsp_check(cli: str, file_rel: str):
    tool = "mcp__lean-lsp__lean_diagnostic_messages"
    prompt = f"Call the MCP tool `{tool}` on the file `{file_rel}`."
    if cli == "claude_code":
        return prompt, _claude_classify, tool, lambda _: True
    if cli == "codex":
        return (
            prompt,
            _codex_classify,
            "mcp_tool_call",
            lambda item: "lean_diagnostic_messages" in (item.get("tool") or ""),
        )
    if cli == "opencode":
        # OpenCode flattens MCP tool names: server_toolname.
        return (
            prompt,
            _opencode_classify,
            "lean-lsp_lean_diagnostic_messages",
            lambda _: True,
        )
    raise AssertionError(cli)


# ---- tests ----------------------------------------------------------------


@pytest.mark.parametrize("cli", CLIS)
def test_skill_invocable(cli: str, repo_root: Path) -> None:
    """Agent invokes a skill that configure_wd copied into .claude/skills/."""
    check = _build_skill_check(cli, "lean-milp-formulation")
    if check is None:
        pytest.skip(f"skill invocation classification not implemented for {cli}")
    action, classifier, tool, matcher = check
    pair_dir = _make_pair_dir(repo_root, f"skill_invocable_{cli}")
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(_load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


@pytest.mark.parametrize("cli", CLIS)
def test_lake_build_fresh_module(cli: str, repo_root: Path) -> None:
    """Regression for the macOS seatbelt EPERM bug: agent builds a fresh
    user module (A.Formulation) that wasn't pre-warmed in the image."""
    pair_dir = _make_pair_dir(repo_root, f"lake_build_fresh_{cli}")
    wd = pair_dir / "wd"
    (wd / "A" / "Formulation.lean").write_text("import Common\n")
    action, classifier, tool, matcher = _build_bash_check(
        cli, "lake build A.Formulation"
    )
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(_load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


@pytest.mark.parametrize("cli", CLIS)
def test_lean_lsp_mcp(cli: str, repo_root: Path) -> None:
    """Agent calls a lean-lsp MCP tool inside the container."""
    action, classifier, tool, matcher = _build_lean_lsp_check(cli, "Common.lean")
    pair_dir = _make_pair_dir(repo_root, f"lean_lsp_mcp_{cli}")
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(_load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


def test_post_hoc_compile_in_container(repo_root: Path) -> None:
    """Entrypoint's `lake env lean` for A/B/Reformulation succeeds when each
    file compiles. Verifies result.json + compile_log.txt flow back to host."""
    if not _cli_available("claude_code"):
        pytest.skip("CLAUDE_CODE_OAUTH_TOKEN not set")
    pair_dir = _make_pair_dir(repo_root, "post_hoc_compile")
    wd = pair_dir / "wd"
    (wd / "Reformulation.lean").write_text("import Common\n")
    harness = _harness("claude_code")
    harness.configure_wd(wd)
    (wd / "prompt.txt").write_text(
        "Do not call any tool. Reply with exactly the word: done."
    )
    harness.run(wd)

    result_path = wd / "result.json"
    assert result_path.exists(), "entrypoint did not write result.json"
    result = json.loads(result_path.read_text())
    assert result["compile_exit"] == 0, (
        f"Reformulation.lean compile failed: {result} "
        f"log={(wd / 'compile_log.txt').read_text()}"
    )
