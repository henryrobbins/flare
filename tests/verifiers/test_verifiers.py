"""End-to-end verifier tests against a fixed subset of dataset pairs.

Each verifier is exercised with a stub that yields the ground-truth verdict:

- ExecutionVerifier: runs the real gurobipy solver — no stubbing needed.
- LLMVerifier: stub LLM client returns ``{is_reformulation, reasoning}``.
- EquivaMapVerifier: stub LLM client returns the ground-truth variable
  mapping (or a "no mapping" sentinel for False pairs).
- FLAREVerifier (in-process): ``DummyHarness`` copies the ground-truth Lean
  files into wd and fakes a successful compile ``result.json``. No Docker.
- FLAREVerifier (Docker, opt-in): ``GroundTruthHarness`` pre-writes the
  ground-truth Lean files into wd and runs a no-op agent inside the real
  flare-agent Docker image so the entrypoint actually invokes ``lake env lean``
"""

from __future__ import annotations

import json
import re
import shutil
from dataclasses import dataclass
from pathlib import Path

import pytest
from formulation_bench import Dataset, Formulation
from milp_flare import Harness, HarnessRunResult
from milp_flare import LLMConfig as HarnessLLMConfig

from src.llm_client import LLMClient, LLMConfig
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.execution.execution import ExecutionVerifier
from src.verify.flare import FLAREVerifier
from src.verify.llm.llm import LLMVerifier

# (problem dir name, formulation A, formulation B, expected reformulation)
PAIRS: list[tuple[str, str, str, bool]] = [
    ("p1", "a", "b", True),
    ("p1", "a", "h", False),
    ("p12", "a", "b", True),
    ("p12", "a", "d", False),
    ("p19", "a", "b", True),
]

PAIR_IDS = [f"{p}_{a}_{b}_{exp}" for p, a, b, exp in PAIRS]


# Ground-truth variable mappings for the EquivaMap test.
#
# Each entry is keyed by `(problem, A-formulation, B-formulation)` and maps an
# A variable to the list of ``{constant, variable}`` terms that EquivaMap
# expects under its `variable_mapping.j2` schema. An empty list signals "no
# mapping found" for that variable, which forces EquivaMap to declare the
# pair non-reformulation.
VARIABLE_MAPPINGS: dict[tuple[str, str, str], dict[str, list[dict]]] = {
    ("p1", "a", "b"): {
        "NumCashMachines": [{"constant": 1.0, "variable": "s"}],
        "NumCardMachines": [{"constant": 1.0, "variable": "r"}],
    },
    ("p1", "a", "h"): {
        "NumCashMachines": [{"constant": 1.0, "variable": "c"}],
        "NumCardMachines": [],
    },
    ("p12", "a", "b"): {
        "x": [{"constant": 1.0, "variable": "x"}],
        "u": [{"constant": 1.0, "variable": "u"}],
    },
    ("p12", "a", "d"): {
        "x": [{"constant": 1.0, "variable": "x"}],
        "u": [{"constant": 1.0, "variable": "u"}],
    },
    ("p19", "a", "b"): {
        "x": [{"constant": 1.0, "variable": "q"}],
        "y": [{"constant": 1.0, "variable": "y"}],
    },
}


@pytest.fixture(params=PAIRS, ids=PAIR_IDS)
def pair(request, dataset: Dataset) -> tuple[Formulation, Formulation, bool]:
    pname, a_letter, b_letter, expected = request.param
    pid = int(pname[1:])
    problem = dataset.problems[pid]
    return problem.formulations[a_letter], problem.formulations[b_letter], expected


@pytest.fixture(params=PAIRS, ids=PAIR_IDS)
def pair_with_key(
    request, dataset: Dataset
) -> tuple[Formulation, Formulation, bool, tuple[str, str, str]]:
    pname, a_letter, b_letter, expected = request.param
    pid = int(pname[1:])
    problem = dataset.problems[pid]
    return (
        problem.formulations[a_letter],
        problem.formulations[b_letter],
        expected,
        (pname, a_letter, b_letter),
    )


# ---------------------------------------------------------------------------
# Dummy LLM client
# ---------------------------------------------------------------------------


@dataclass
class _StubResponse:
    """A single canned JSON response with deterministic token usage."""

    payload: dict
    input_tokens: int = 0
    output_tokens: int = 0


class DummyLLMClient(LLMClient):
    """LLM stub that returns pre-baked JSON payloads.

    Two construction modes:

    - ``DummyLLMClient(_StubResponse(...))`` — reuse one payload for every
      call (LLMVerifier only invokes the client once).
    - ``DummyLLMClient.for_variables(mapping)`` — return different payloads
      keyed by the A-variable referenced in the user prompt. EquivaMap calls
      the client once per A variable, so we look up the right mapping by
      grepping the rendered prompt for the variable name.
    """

    def __init__(
        self,
        single: _StubResponse | None = None,
        by_variable: dict[str, _StubResponse] | None = None,
    ) -> None:
        self._single = single
        self._by_variable = by_variable or {}
        self._config = LLMConfig(model="dummy-model")

    @classmethod
    def for_variables(cls, mapping: dict[str, list[dict]]) -> DummyLLMClient:
        return cls(
            by_variable={
                var: _StubResponse(
                    payload={
                        "terms": (
                            terms if terms else [{"constant": "none", "variable": ""}]
                        )
                    }
                )
                for var, terms in mapping.items()
            }
        )

    @property
    def config(self) -> LLMConfig:
        return self._config

    def complete(self, system: str, user: str) -> str:
        raise NotImplementedError

    def complete_json_with_usage(
        self, system: str, user: str, schema: dict
    ) -> tuple[dict, dict]:
        if self._single is not None:
            resp = self._single
        else:
            # EquivaMap renders the prompt with `**Name:** <var>` as the
            # very first variable heading (the A variable being mapped),
            # followed by `**Name:** <b_var>` entries for each B variable.
            # The first match is the A variable we need.
            match = re.search(r"\*\*Name:\*\*\s*([A-Za-z_]\w*)", user)
            if match is None or match.group(1) not in self._by_variable:
                raise AssertionError(
                    "DummyLLMClient could not identify A variable in prompt"
                )
            var = match.group(1)
            resp = self._by_variable[var]
        usage = {
            "input_tokens": resp.input_tokens,
            "output_tokens": resp.output_tokens,
        }
        return resp.payload, usage


# ---------------------------------------------------------------------------
# In-process FLARE harness (no Docker)
# ---------------------------------------------------------------------------


class DummyHarness(Harness):
    """Harness that bypasses Docker and pre-writes ground-truth Lean files.

    For True pairs, the harness copies the dataset's ``Formulation.lean``
    files and the matching ``reformulations/pX/<a>_<b>.lean`` into the
    agent working directory and writes a fake ``result.json`` reporting a
    successful compile. For False pairs, it writes a ``NOT REFORMULATION``
    marker, which FLAREVerifier picks up via its agent-decision check.
    """

    name = "dummy"

    def __init__(
        self,
        repo_root: Path,
        a: Formulation,
        b: Formulation,
        expected: bool,
    ) -> None:
        super().__init__(HarnessLLMConfig(model="dummy-model"))
        self.repo_root = repo_root
        self.a = a
        self.b = b
        self.expected = expected

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        return

    def _agent_docker_args(self) -> list[str]:
        return []

    def _agent_command(self) -> str:
        return ""

    def _parse_lines(self, lines: list[str]) -> dict:
        return {
            "stop_reason": "end_turn",
            "input_tokens": 0,
            "output_tokens": 0,
            "cost_usd": 0.0,
        }

    def run(self, wd: Path) -> HarnessRunResult:
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
            (wd / "compile_log.txt").write_text("")
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


# ---------------------------------------------------------------------------
# Docker-backed FLARE harness (real container, no-op agent)
# ---------------------------------------------------------------------------


# Match either fully-qualified `import dataset.problems.pX.formulations.Y.Formulation`
# or the trailing bare `import Y.Formulation` form; rewrite both to the
# in-container module name (A.Formulation / B.Formulation).
_FORM_IMPORT = re.compile(
    r"^import\s+(?:dataset\.problems\.p\d+\.formulations\.)?([a-z])\.Formulation\s*$",
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

    The dataset's reformulation file imports the formulations by their full
    `dataset.problems.pX.formulations.Y.Formulation` path. Inside the
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
        super().__init__(HarnessLLMConfig(model="dummy-model"))
        self.repo_root = repo_root
        self.a = a
        self.b = b
        self.expected = expected

    def configure_wd(self, wd: Path, repo_root: Path) -> None:
        super().configure_wd(wd, repo_root)
        if self.expected:
            _copy_ground_truth(wd, repo_root, self.a, self.b)
        else:
            (wd / "Reformulation.lean").write_text(
                "-- NOT REFORMULATION\n-- ground-truth harness verdict\n"
            )

    def _agent_docker_args(self) -> list[str]:
        return []

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


# Skip invalid TSP cutting plane (p12.a -> p12.d) for execution and EquivaMap
# verifiers since both are known to be incorrect for this reformulation
EXEC_SKIP: set[tuple[str, str, str]] = {("p12", "a", "d")}
EQUIVAMAP_SKIP: set[tuple[str, str, str]] = {("p12", "a", "d")}


@pytest.mark.gurobi
def test_execution_verifier(
    pair_with_key: tuple[Formulation, Formulation, bool, tuple[str, str, str]],
    tmp_path: Path,
) -> None:
    a, b, expected, key = pair_with_key
    if key in EXEC_SKIP:
        pytest.skip(
            f"objective parity makes ExecutionVerifier indistinguishable on {key}"
        )
    result = ExecutionVerifier().verify(a, b, tmp_path)
    assert result.is_reformulation is expected


def test_llm_verifier(
    pair: tuple[Formulation, Formulation, bool], tmp_path: Path
) -> None:
    a, b, expected = pair
    client = DummyLLMClient(
        single=_StubResponse(
            payload={"is_reformulation": expected, "reasoning": "stub"},
        )
    )
    result = LLMVerifier(client).verify(a, b, tmp_path)
    assert result.is_reformulation is expected


@pytest.mark.gurobi
def test_equivamap_verifier(
    pair_with_key: tuple[Formulation, Formulation, bool, tuple[str, str, str]],
    tmp_path: Path,
) -> None:
    a, b, expected, key = pair_with_key
    if key in EQUIVAMAP_SKIP:
        pytest.skip(f"trivial mapping doesn't distinguish ground truth on {key}")
    mapping = VARIABLE_MAPPINGS[key]
    client = DummyLLMClient.for_variables(mapping)
    result = EquivaMapVerifier(client).verify(a, b, tmp_path)
    assert result.is_reformulation is expected


def test_flare_verifier(
    pair: tuple[Formulation, Formulation, bool],
    repo_root: Path,
    tmp_path: Path,
) -> None:
    a, b, expected = pair
    harness = DummyHarness(repo_root=repo_root, a=a, b=b, expected=expected)
    verifier = FLAREVerifier(repo_root=repo_root, harness=harness)
    result = verifier.verify(a, b, tmp_path)
    assert result.is_reformulation is expected


@pytest.mark.docker
def test_flare_verifier_docker(
    pair: tuple[Formulation, Formulation, bool],
    repo_root: Path,
    tmp_path: Path,
) -> None:
    """End-to-end FLAREVerifier run against the real flare-agent Docker image.

    The "agent" is a shell no-op; configure_wd pre-writes the ground-truth
    Lean files so the entrypoint's ``lake env lean`` invocations exercise
    real compilation. Requires the ``flare-agent:latest`` image. No model
    credentials are consumed.
    """
    a, b, expected = pair
    harness = GroundTruthHarness(repo_root=repo_root, a=a, b=b, expected=expected)
    verifier = FLAREVerifier(repo_root=repo_root, harness=harness)
    result = verifier.verify(a, b, tmp_path)
    assert result.is_reformulation is expected
