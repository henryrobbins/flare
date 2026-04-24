import json
from pathlib import Path

from milp_eq_tools import Formulation

from .checker import CheckResult, EquivalenceChecker
from .llm_client import LLMClient

_SYSTEM = (
    "You are an expert in mathematical optimization. "
    "Decide if two formulations represent equivalent optimization problems."
)


def _problem_info(f: Formulation) -> dict:
    return {
        "variables": {
            name: {"description": var.description, "type": var.type.value}
            for name, var in f.variables.items()
        },
        "constraints": [
            {"description": c.description, "formulation": c.formulation}
            for c in f.constraints
            if c.explicit
        ],
        "objective": {
            "description": f.objective.description,
            "formulation": f.objective.formulation,
        },
    }


def _build_prompt(info_a: dict, info_b: dict) -> str:
    return (
        "You are given two optimization problem formulations.\n"
        "Decide if they are equivalent formulations.\n\n"
        f"Formulation A:\n{json.dumps(info_a, indent=2)}\n\n"
        f"Formulation B:\n{json.dumps(info_b, indent=2)}\n\n"
        "Provide 1-2 sentences of reasoning, then end your response with exactly one of:\n"
        "Equivalent\n"
        "Not Equivalent\n\n"
        'When uncertain, respond "Not Equivalent".'
    )


class NaiveLLMChecker(EquivalenceChecker):
    def __init__(self, runs_dir: Path, client: LLMClient) -> None:
        super().__init__(runs_dir)
        self.client = client

    @property
    def name(self) -> str:
        return "naive_llm"

    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult:
        artifacts_dir = self.runs_dir / "pairs" / pair_id / "naive_llm"
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        info_a = _problem_info(a)
        info_b = _problem_info(b)
        (artifacts_dir / "problem_info_a.json").write_text(json.dumps(info_a, indent=2))
        (artifacts_dir / "problem_info_b.json").write_text(json.dumps(info_b, indent=2))

        prompt = _build_prompt(info_a, info_b)
        (artifacts_dir / "prompt.txt").write_text(prompt)

        response = self.client.complete(_SYSTEM, prompt)
        (artifacts_dir / "response.txt").write_text(response)

        last_line = next(
            (line.strip() for line in reversed(response.splitlines()) if line.strip()),
            "",
        ).lower()
        is_equiv = last_line == "equivalent"

        nonempty = [line for line in response.splitlines() if line.strip()]
        reasoning = "\n".join(nonempty[:-1]) if len(nonempty) > 1 else ""

        meta = {"is_equivalent": is_equiv, "reasoning": reasoning}
        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return CheckResult(
            is_equivalent=is_equiv,
            method=self.name,
            artifacts_dir=artifacts_dir,
            metadata=meta,
        )
