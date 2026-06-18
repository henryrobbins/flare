"""End-to-end FLARE tests against a fixed subset of dataset pairs.

Two harnesses exercise the verifier without burning model credentials:

- ``DummyHarness`` (in-process): copies the ground-truth Lean files into
  wd and fakes a successful compile ``result.json``. No Docker.
- ``GroundTruthHarness`` (Docker, opt-in): pre-writes the ground-truth
  Lean files into wd and runs a no-op agent inside the real
  flare-agent Docker image so the entrypoint actually invokes
  ``lake env lean``.
"""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path
from typing import Any

import pytest
from formulation_bench import Dataset, Formulation

from milp_flare import (
    FLARE,
    FormulationInput,
    Harness,
    HarnessRunResult,
)

# (problem dir name, formulation A, formulation B, expected reformulation)
PAIRS: list[tuple[str, str, str, bool]] = [
    ("p1", "a", "b", True),
    ("p1", "a", "h", False),
    ("p12", "a", "b", True),
    ("p12", "a", "d", False),
    ("p19", "a", "b", True),
]

PAIR_IDS = [f"{p}_{a}_{b}_{exp}" for p, a, b, exp in PAIRS]


@pytest.fixture(params=PAIRS, ids=PAIR_IDS)
def pair(request, dataset: Dataset) -> tuple[Formulation, Formulation, bool]:
    pname, a_letter, b_letter, expected = request.param
    pid = int(pname[1:])
    problem = dataset.problems[pid]
    return problem.formulations[a_letter], problem.formulations[b_letter], expected


# ---------------------------------------------------------------------------
# Ground-truth file copy + import rewriting
# ---------------------------------------------------------------------------


# Match a fully-qualified `import problems.pX.formulations.Y.Formulation`
# (the lake project's srcDir is `dataset/`, so that is the module path) or
# the trailing bare `import Y.Formulation` form; rewrite both to the
# in-container module name (A.Formulation / B.Formulation).
_FORM_IMPORT = re.compile(
    r"^import\s+(?:problems\.p\d+\.formulations\.)?([a-z])\.Formulation\s*$",
    re.MULTILINE,
)


def _rewrite_reformulation_imports(text: str, a_letter: str, b_letter: str) -> str:
    """Rewrite formulation imports in a dataset reformulation file to the
    Docker container's local module names (A.Formulation / B.Formulation)."""

    def repl(m: re.Match) -> str:
        letter = m.group(1)
        if letter == a_letter:
            return "import A.Formulation"
        if letter == b_letter:
            return "import B.Formulation"
        return m.group(0)

    return _FORM_IMPORT.sub(repl, text)


def _copy_ground_truth(
    wd: Path, repo_root: Path, a: Formulation, b: Formulation
) -> None:
    """Populate wd with the ground-truth Formulation.lean + Reformulation.lean.

    The dataset's reformulation file imports the formulations by their
    `problems.pX.formulations.Y.Formulation` module path. Inside the
    container that module path doesn't resolve, so we rewrite the imports
    to the local `A.Formulation` / `B.Formulation` modules served by the
    docker lakefile.
    """
    shutil.copy2(a.path / "Formulation.lean", wd / "A" / "Formulation.lean")
    shutil.copy2(b.path / "Formulation.lean", wd / "B" / "Formulation.lean")
    pname = a.path.parent.parent.name  # e.g. "p1"
    reform_src = (
        repo_root
        / "dataset"
        / "reformulations"
        / pname
        / f"{a.path.name}_{b.path.name}.lean"
    )
    rewritten = _rewrite_reformulation_imports(
        reform_src.read_text(), a.path.name, b.path.name
    )
    (wd / "Reformulation.lean").write_text(rewritten)


# ---------------------------------------------------------------------------
# In-process FLARE harness (no Docker)
# ---------------------------------------------------------------------------


class DummyHarness(Harness):
    """Harness that bypasses Docker and pre-writes ground-truth Lean files.

    For True pairs, the harness copies the dataset's ``Formulation.lean``
    files and the matching ``reformulations/pX/<a>_<b>.lean`` into the
    agent working directory and writes a fake ``result.json`` reporting a
    successful compile. For False pairs, it writes a ``NOT REFORMULATION``
    marker, which FLARE picks up via its agent-decision check.
    """

    name = "dummy"

    def __init__(
        self,
        repo_root: Path,
        a: Formulation,
        b: Formulation,
        expected: bool,
    ) -> None:
        super().__init__(model="dummy-model")
        self.repo_root = repo_root
        self.a = a
        self.b = b
        self.expected = expected

    def configure_wd(self, wd: Path) -> None:
        return

    def _agent_command(self) -> str:
        return ""

    def _parse_lines(self, lines: list[str]) -> dict:
        return {
            "stop_reason": "end_turn",
            "input_tokens": 0,
            "output_tokens": 0,
            "cost_usd": 0.0,
        }

    def run(self, wd: Path, **kwargs: Any) -> HarnessRunResult:
        if self.expected:
            _copy_ground_truth(wd, self.repo_root, self.a, self.b)
            (wd / "result.json").write_text(
                json.dumps(
                    {
                        "form_a_compile_exit": 0,
                        "form_b_compile_exit": 0,
                        "compile_exit": 0,
                    }
                )
            )
            (wd / "compile_log.txt").write_text(
                "'reformulation' depends on axioms: "
                "[propext, Classical.choice, Quot.sound]\n"
            )
        else:
            (wd / "Reformulation.lean").write_text(
                "-- NOT REFORMULATION\n-- stub harness verdict\n"
            )

        return HarnessRunResult(
            duration_s=0.0,
            cost_usd=0.0,
            input_tokens=0,
            output_tokens=0,
            stop_reason="end_turn",
        )


class BadAxiomHarness(DummyHarness):
    """DummyHarness variant whose compile log reports a non-standard axiom.

    Every Lean file still compiles cleanly, so this isolates the axiom check:
    FLARE must reject the pair purely because the proof depends on an axiom
    outside the standard set.
    """

    name = "bad_axiom"

    def run(self, wd: Path, **kwargs: Any) -> HarnessRunResult:
        result = super().run(wd)
        (wd / "compile_log.txt").write_text(
            "'reformulation' depends on axioms: [propext, Classical.choice, P1.cheat]\n"
        )
        return result


# ---------------------------------------------------------------------------
# Docker-backed FLARE harness (real container, no-op agent)
# ---------------------------------------------------------------------------


class GroundTruthHarness(Harness):
    """Real-Docker harness whose "agent" is a shell no-op.

    ``configure_wd`` pre-populates wd with the ground-truth Lean files for
    True pairs (or a ``NOT REFORMULATION`` marker for False pairs) and
    writes a trivial ``agent.sh`` that just exits 0. The base ``Harness.run``
    then invokes Docker as usual; the entrypoint runs ``agent.sh`` (a no-op)
    and then ``lake env lean`` on each of the three Lean files, producing a
    real ``result.json``.
    """

    name = "ground_truth"

    def __init__(
        self,
        repo_root: Path,
        a: Formulation,
        b: Formulation,
        expected: bool,
    ) -> None:
        super().__init__(model="dummy-model")
        self.repo_root = repo_root
        self.a = a
        self.b = b
        self.expected = expected

    def configure_wd(self, wd: Path) -> None:
        super().configure_wd(wd)
        if self.expected:
            _copy_ground_truth(wd, self.repo_root, self.a, self.b)
        else:
            (wd / "Reformulation.lean").write_text(
                "-- NOT REFORMULATION\n-- ground-truth harness verdict\n"
            )

    def _agent_command(self) -> str:
        # Build A.Formulation and B.Formulation so that the entrypoint's
        # subsequent `lake env lean Reformulation.lean` can resolve
        # `import A.Formulation` / `import B.Formulation`. Without this,
        # the formulation oleans don't exist on disk and the proof file
        # fails import resolution.
        return "#!/usr/bin/env bash\nset -e\nlake build A.Formulation B.Formulation\n"

    def _parse_lines(self, lines: list[str]) -> dict:
        return {
            "stop_reason": "end_turn",
            "input_tokens": 0,
            "output_tokens": 0,
            "cost_usd": 0.0,
        }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


# The DummyHarness / GroundTruthHarness pre-write the Lean files and never
# read formulation.md, so any markdown is fine.
def _inputs(
    a: Formulation, b: Formulation
) -> tuple[FormulationInput, FormulationInput]:
    return (
        FormulationInput(formulation_md="", solve_py=a.gen_solve_py()),
        FormulationInput(formulation_md="", solve_py=b.gen_solve_py()),
    )


def test_flare_verifier(
    pair: tuple[Formulation, Formulation, bool],
    repo_root: Path,
    tmp_path: Path,
) -> None:
    a, b, expected = pair
    harness = DummyHarness(repo_root=repo_root, a=a, b=b, expected=expected)
    verifier = FLARE(harness=harness)
    a_in, b_in = _inputs(a, b)
    result = verifier.verify(a_in, b_in, tmp_path)
    assert result.is_reformulation is expected


def test_flare_verifier_rejects_extra_axiom(
    repo_root: Path,
    tmp_path: Path,
    dataset: Dataset,
) -> None:
    """A proof depending on an axiom outside the standard set fails, even when
    every Lean file compiles cleanly."""
    problem = dataset.problems[1]
    a, b = problem.formulations["a"], problem.formulations["b"]
    harness = BadAxiomHarness(repo_root=repo_root, a=a, b=b, expected=True)
    verifier = FLARE(harness=harness)
    a_in, b_in = _inputs(a, b)
    result = verifier.verify(a_in, b_in, tmp_path)
    assert result.is_reformulation is False
    assert result.metadata["no_new_axioms"] is False
    assert "P1.cheat" in result.metadata["axioms"]


@pytest.mark.docker
def test_flare_verifier_docker(
    pair: tuple[Formulation, Formulation, bool],
    repo_root: Path,
    tmp_path: Path,
) -> None:
    """End-to-end FLARE run against the real flare-agent Docker image.

    The "agent" is a shell no-op; configure_wd pre-writes the ground-truth
    Lean files so the entrypoint's ``lake env lean`` invocations exercise
    real compilation. Requires the ``flare-agent:latest`` image. No model
    credentials are consumed.
    """
    a, b, expected = pair
    harness = GroundTruthHarness(repo_root=repo_root, a=a, b=b, expected=expected)
    verifier = FLARE(harness=harness)
    a_in, b_in = _inputs(a, b)
    result = verifier.verify(a_in, b_in, tmp_path)
    assert result.is_reformulation is expected
