"""End-to-end verifier tests against a fixed subset of dataset pairs.

Each verifier is exercised with a stub that yields the ground-truth verdict:

- ExecutionVerifier: runs the real gurobipy solver — no stubbing needed.
- LLMVerifier: stub LLM client returns ``{is_reformulation, reasoning}``.
- EquivaMapVerifier: stub LLM client returns the ground-truth variable
  mapping (or a "no mapping" sentinel for False pairs).

FLAREVerifier tests live in ``packages/milp_flare/tests/``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import pytest
from formulation_bench import Dataset, Reformulation

from src.llm_client import LLMClient, LLMConfig, TruncatedResponseError
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.execution.execution import ExecutionVerifier
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


def lookup_reformulation(
    dataset: Dataset, pname: str, a_letter: str, b_letter: str
) -> Reformulation:
    return next(
        r
        for r in dataset.reformulations
        if r.a.problem.path.name == pname
        and r.a.path.name == a_letter
        and r.b.path.name == b_letter
    )


@pytest.fixture(params=PAIRS, ids=PAIR_IDS)
def pair(request, dataset: Dataset) -> tuple[Reformulation, bool]:
    pname, a_letter, b_letter, expected = request.param
    return lookup_reformulation(dataset, pname, a_letter, b_letter), expected


@pytest.fixture(params=PAIRS, ids=PAIR_IDS)
def pair_with_key(
    request, dataset: Dataset
) -> tuple[Reformulation, bool, tuple[str, str, str]]:
    pname, a_letter, b_letter, expected = request.param
    return (
        lookup_reformulation(dataset, pname, a_letter, b_letter),
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
# Tests
# ---------------------------------------------------------------------------


# Skip invalid TSP cutting plane (p12.a -> p12.d) for execution and EquivaMap
# verifiers since both are known to be incorrect for this reformulation
EXEC_SKIP: set[tuple[str, str, str]] = {("p12", "a", "d")}
EQUIVAMAP_SKIP: set[tuple[str, str, str]] = {("p12", "a", "d")}


def test_execution_verifier(
    pair_with_key: tuple[Reformulation, bool, tuple[str, str, str]],
    tmp_path: Path,
) -> None:
    reform, expected, key = pair_with_key
    if key in EXEC_SKIP:
        pytest.skip(
            f"objective parity makes ExecutionVerifier indistinguishable on {key}"
        )
    result = ExecutionVerifier().verify(reform, tmp_path)
    assert result.is_reformulation is expected


def test_llm_verifier(pair: tuple[Reformulation, bool], tmp_path: Path) -> None:
    reform, expected = pair
    client = DummyLLMClient(
        single=_StubResponse(
            payload={"is_reformulation": expected, "reasoning": "stub"},
        )
    )
    result = LLMVerifier(client).verify(reform, tmp_path)
    assert result.is_reformulation is expected


def test_llm_verifier_saves_partial_on_truncation(
    pair: tuple[Reformulation, bool], tmp_path: Path
) -> None:
    reform, _ = pair

    class TruncatingClient(DummyLLMClient):
        def complete_json_with_usage(
            self, system: str, user: str, schema: dict
        ) -> tuple[dict, dict]:
            raise TruncatedResponseError("truncated", '{"is_reformulation": tr')

    with pytest.raises(TruncatedResponseError):
        LLMVerifier(TruncatingClient()).verify(reform, tmp_path)
    assert (tmp_path / "response.partial.txt").read_text() == '{"is_reformulation": tr'


def test_llm_verifier_prompt_includes_parameter_map(
    pair: tuple[Reformulation, bool], tmp_path: Path
) -> None:
    reform, expected = pair
    client = DummyLLMClient(
        single=_StubResponse(
            payload={"is_reformulation": expected, "reasoning": "stub"},
        )
    )
    LLMVerifier(client).verify(reform, tmp_path)
    prompt = (tmp_path / "prompt.txt").read_text()
    assert "## Parameter Mapping" in prompt
    assert reform.parameter_map.render_markdown() in prompt


def test_equivamap_verifier(
    pair_with_key: tuple[Reformulation, bool, tuple[str, str, str]],
    tmp_path: Path,
) -> None:
    reform, expected, key = pair_with_key
    if key in EQUIVAMAP_SKIP:
        pytest.skip(f"trivial mapping doesn't distinguish ground truth on {key}")
    mapping = VARIABLE_MAPPINGS[key]
    client = DummyLLMClient.for_variables(mapping)
    result = EquivaMapVerifier(client).verify(reform, tmp_path)
    assert result.is_reformulation is expected


def test_equivamap_rejects_ill_shaped_mapping(dataset: Dataset, tmp_path: Path) -> None:
    """A mapping that can't pin every entry of A is a failure, not a pass.

    Summing B variables of different shapes used to truncate to the shorter
    one, leaving A under-constrained and free to re-optimize into a match.
    """
    reform = lookup_reformulation(dataset, "p12", "a", "b")
    client = DummyLLMClient.for_variables(
        {
            "x": [
                {"constant": 1.0, "variable": "x"},
                {"constant": 1.0, "variable": "u"},
            ],
            "u": [{"constant": 1.0, "variable": "u"}],
        }
    )
    result = EquivaMapVerifier(client).verify(reform, tmp_path)
    assert result.is_reformulation is False
    assert "invalid_mapping" in result.metadata
