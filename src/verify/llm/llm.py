import json
from pathlib import Path

from milp_eq_tools import Formulation

from src.verify.base import CheckResult, EquivalenceVerifier
from src.verify.prompts import problem_info
from src.verify.llm.prompts import render_equivalence
from src.llm_client import LLMClient


class LLMVerifier(EquivalenceVerifier):
    def __init__(self, runs_dir: Path, client: LLMClient) -> None:
        super().__init__(runs_dir)
        self.client = client

    @property
    def name(self) -> str:
        return "llm"

    def check(self, a: Formulation, b: Formulation, pair_id: str) -> CheckResult:
        artifacts_dir = self.runs_dir / "pairs" / pair_id / "llm"
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        info_a = problem_info(a)
        info_b = problem_info(b)
        (artifacts_dir / "problem_info_a.json").write_text(json.dumps(info_a, indent=2))
        (artifacts_dir / "problem_info_b.json").write_text(json.dumps(info_b, indent=2))

        rendered = render_equivalence(a, b)
        (artifacts_dir / "prompt.txt").write_text(rendered.user)

        response = self.client.complete(rendered.system, rendered.user)
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
