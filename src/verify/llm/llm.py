import dataclasses
import json
import time
from pathlib import Path

from milp_eq_tools import Formulation

from src.verify.base import EquivalenceResult, EquivalenceVerifier
from src.verify.llm.prompts import EQUIVALENCE_SCHEMA, render_equivalence
from src.llm_client import LLMClient, compute_cost_usd


class LLMVerifier(EquivalenceVerifier):
    def __init__(self, client: LLMClient) -> None:
        self.client = client

    @property
    def name(self) -> str:
        return "llm"

    def method_config(self) -> dict:
        return {"llm": dataclasses.asdict(self.client.config)}

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> EquivalenceResult:
        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        rendered = render_equivalence(a, b)
        (artifacts_dir / "prompt.txt").write_text(rendered.user)

        start = time.time()
        parsed, usage = self.client.complete_json_with_usage(
            rendered.system, rendered.user, EQUIVALENCE_SCHEMA
        )
        duration_s = round(time.time() - start, 1)
        (artifacts_dir / "response.json").write_text(json.dumps(parsed, indent=2))

        is_equiv = bool(parsed["is_equivalent"])
        reasoning = parsed.get("reasoning", "")
        cost_usd = compute_cost_usd(
            self.client.config.model, usage["input_tokens"], usage["output_tokens"]
        )

        return EquivalenceResult(
            is_equivalent=is_equiv,
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=duration_s,
            cost_usd=cost_usd,
            metadata={"reasoning": reasoning, **usage},
        )
