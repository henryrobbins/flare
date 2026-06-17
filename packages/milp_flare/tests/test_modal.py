"""Integration tests for the Modal Harness across all three CLIs.

The Modal analog of ``test_docker.py``: the same agent behaviors (skill
invocation, a fresh ``lake build``, a lean-lsp MCP call, and the entrypoint's
post-hoc compile) exercised through a ``ModalRunner`` instead of the local
Docker backend. These tests make real model calls inside a Modal Sandbox. They
are marked ``modal`` and excluded by ``pytest -m 'not modal'``.

The CLI-specific machinery (prompt template, per-CLI classifiers, action
builders, credential availability checks) is compute-agnostic, so it is reused
verbatim from ``test_docker.py`` rather than duplicated; only the harness
construction differs (it injects a ``ModalRunner``).

Prerequisites:
  - a configured Modal token (``modal token new``)
  - ``milp-flare build-modal-image`` has been run (publishes the ``flare-agent``
    named image used by the Sandbox)
  - CLAUDE_CODE_OAUTH_TOKEN in env for claude_code
  - OPENAI_API_KEY in env (or ~/.codex/auth.json on host) for codex
  - DEEPSEEK_API_KEY in env for opencode (tests use deepseek-chat to
    avoid burning Anthropic spend on integration runs)
"""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest

from milp_flare import HARNESSES, Harness, ModalRunner

# Reuse the compute-agnostic helpers from the docker integration module. It is
# loaded by file path (not a bare ``import``) so this works under both pytest
# import modes — ``prepend`` (the package default, used by ``-m modal``) and
# ``importlib`` (the repo-root default). Loading test_docker.py executes its
# body, which only defines functions/constants and has no import-time side
# effects, so it is safe to load here as a plain helper module.
_spec = importlib.util.spec_from_file_location(
    "milp_flare_agent_integration",
    Path(__file__).with_name("test_docker.py"),
)
assert _spec is not None and _spec.loader is not None
dk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dk)

pytestmark = pytest.mark.modal


def _harness(cli: str) -> Harness:
    """Build the CLI's harness configured to run on a Modal Sandbox."""
    return HARNESSES[cli](model=dk._model_for(cli), effort="low", runner=ModalRunner())


def _run(cli: str, repo_root: Path, pair_dir: Path, action: str) -> Path:
    """Configure ``wd``, run the one-call prompt on Modal, return the JSONL path.

    Mirrors ``test_docker._run`` but drives the Modal-backed harness.
    """
    if not dk._cli_available(cli):
        pytest.skip(f"credentials for {cli} not available")
    harness = _harness(cli)
    wd = pair_dir / "wd"
    harness.configure_wd(wd)
    (wd / "prompt.txt").write_text(dk.ONE_CALL_PROMPT.format(action=action))
    harness.run(wd)
    return wd / "agent_output.jsonl"


# ---- tests (parallel to test_docker.py) -----------------------------------


@pytest.mark.parametrize("cli", dk.CLIS)
def test_skill_invocable(cli: str, repo_root: Path) -> None:
    """Agent invokes a skill that configure_wd copied into .claude/skills/."""
    check = dk._build_skill_check(cli, "lean-milp-formulation")
    if check is None:
        pytest.skip(f"skill invocation classification not implemented for {cli}")
    action, classifier, tool, matcher = check
    pair_dir = dk._make_pair_dir(repo_root, f"modal_skill_invocable_{cli}")
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(dk._load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


@pytest.mark.parametrize("cli", dk.CLIS)
def test_lake_build_fresh_module(cli: str, repo_root: Path) -> None:
    """Agent builds a fresh user module (A.Formulation) inside the Sandbox."""
    pair_dir = dk._make_pair_dir(repo_root, f"modal_lake_build_fresh_{cli}")
    wd = pair_dir / "wd"
    (wd / "A" / "Formulation.lean").write_text("import Common\n")
    action, classifier, tool, matcher = dk._build_bash_check(
        cli, "lake build A.Formulation"
    )
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(dk._load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


@pytest.mark.parametrize("cli", dk.CLIS)
def test_lean_lsp_mcp(cli: str, repo_root: Path) -> None:
    """Agent calls a lean-lsp MCP tool inside the Sandbox."""
    action, classifier, tool, matcher = dk._build_lean_lsp_check(cli, "Common.lean")
    pair_dir = dk._make_pair_dir(repo_root, f"modal_lean_lsp_mcp_{cli}")
    jsonl = _run(cli, repo_root, pair_dir, action)
    outcome, evidence = classifier(dk._load_events(jsonl), tool, matcher)
    assert outcome == "success", f"{outcome}: {evidence}. jsonl={jsonl}"


def test_post_hoc_compile_in_sandbox(repo_root: Path) -> None:
    """Entrypoint's `lake env lean` for A/B/Reformulation succeeds when each
    file compiles. Verifies result.json + compile_log.txt flow back to host."""
    if not dk._cli_available("claude_code"):
        pytest.skip("CLAUDE_CODE_OAUTH_TOKEN not set")
    pair_dir = dk._make_pair_dir(repo_root, "modal_post_hoc_compile")
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
