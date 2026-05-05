import dataclasses
import json
import time
from pathlib import Path

from milp_eq_tools import Formulation

from src.verify.base import ReformulationResult, ReformulationVerifier
from src.verify.llm.prompts import REFORMULATION_SCHEMA, render_reformulation
from src.llm_client import LLMClient, compute_cost_usd


class LLMVerifier(ReformulationVerifier):
    def __init__(
        self,
        client: LLMClient,
        name: str = "llm",
        template: str = "reformulation.j2",
        include_implicit: bool = True,
    ) -> None:
        self.client = client
        self._name = name
        self.template = template
        self.include_implicit = include_implicit

    @property
    def name(self) -> str:
        return self._name

    def method_config(self) -> dict:
        return {
            "llm": dataclasses.asdict(self.client.config),
            "template": self.template,
            "include_implicit": self.include_implicit,
        }

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        rendered = render_reformulation(
            a, b, template=self.template, include_implicit=self.include_implicit
        )
        (artifacts_dir / "prompt.txt").write_text(rendered.user)

        start = time.time()
        parsed, usage = self.client.complete_json_with_usage(
            rendered.system, rendered.user, REFORMULATION_SCHEMA
        )
        duration_s = round(time.time() - start, 1)
        (artifacts_dir / "response.json").write_text(json.dumps(parsed, indent=2))

        is_reform = bool(parsed["is_reformulation"])
        reasoning = parsed.get("reasoning", "")
        cost_usd = compute_cost_usd(
            self.client.config.model, usage["input_tokens"], usage["output_tokens"]
        )

        return ReformulationResult(
            is_reformulation=is_reform,
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=duration_s,
            cost_usd=cost_usd,
            metadata={"reasoning": reasoning, **usage},
        )
