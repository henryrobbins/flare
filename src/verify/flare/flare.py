import dataclasses
import json
import re
from pathlib import Path

from formulation_bench import Formulation

from src.prompts import render_formulation
from src.verify.base import ReformulationResult, ReformulationVerifier
from src.verify.flare.harness import Harness
from src.verify.flare.prompts import render_agent_prompt


class FLAREVerifier(ReformulationVerifier):
    def __init__(self, repo_root: Path, harness: Harness | None = None) -> None:
        # `harness` is optional so that callers that only need ._evaluate
        # (e.g., scripts/reeval_flare.py) can construct a verifier without
        # configuring a Docker harness.
        self.repo_root = repo_root
        self.harness = harness

    @property
    def name(self) -> str:
        return "flare"

    def method_config(self) -> dict:
        if self.harness is None:
            return {}
        return self.harness.method_config()

    def verify(
        self, a: Formulation, b: Formulation, output_path: Path
    ) -> ReformulationResult:
        if self.harness is None:
            raise RuntimeError("FLAREVerifier.verify requires a Harness")

        artifacts_dir = output_path
        artifacts_dir.mkdir(parents=True, exist_ok=True)
        (artifacts_dir / "config.json").write_text(
            json.dumps(self.method_config(), indent=2)
        )

        wd = artifacts_dir / "wd"
        self._setup_wd(wd, a, b)
        self.harness.configure_wd(wd, self.repo_root)

        prompt = render_agent_prompt()
        (artifacts_dir / "prompt.txt").write_text(prompt)

        jsonl_path = artifacts_dir / "agent_output.jsonl"
        print(f"  [flare] monitor: tail -f {jsonl_path}")

        run_result = self.harness.run(prompt, wd, jsonl_path)

        meta = self._evaluate(wd)
        meta.update(dataclasses.asdict(run_result))

        (artifacts_dir / "result.json").write_text(json.dumps(meta, indent=2))

        return ReformulationResult(
            is_reformulation=meta["is_reformulation"],
            method=self.name,
            artifacts_dir=artifacts_dir,
            duration_s=meta.get("duration_s"),
            cost_usd=meta.get("cost_usd"),
            metadata=meta,
        )

    def _setup_wd(self, wd: Path, a: Formulation, b: Formulation) -> None:
        # The container has the lake skeleton + Common pre-built at /workspace/,
        # so we only need to drop per-pair inputs into wd. The harness adds
        # .claude/ and .mcp.json afterward via configure_wd.
        wd.mkdir(parents=True, exist_ok=True)
        for label, form in [("A", a), ("B", b)]:
            form_dir = wd / label
            form_dir.mkdir(exist_ok=True)
            (form_dir / "formulation.md").write_text(render_formulation(form))
            (form_dir / "solve.py").write_text(form.gurobipy_code)
            (form_dir / "Formulation.lean").write_text("")
        (wd / "Reformulation.lean").write_text("")

    def _evaluate(self, wd: Path) -> dict:
        # The container entrypoint writes result.json + compile_log.txt next
        # to wd (i.e. into the bind-mounted pair_dir).
        artifacts_dir = wd.parent
        form_a_lean = wd / "A" / "Formulation.lean"
        form_b_lean = wd / "B" / "Formulation.lean"
        reform_file = wd / "Reformulation.lean"

        reform_content = reform_file.read_text().strip() if reform_file.exists() else ""

        # Normalize the first meaningful line: strip Lean comment markers so
        # "-- NOT REFORMULATION: ..." is detected the same as "NOT REFORMULATION: ...".
        first_line = next(
            (l.strip() for l in reform_content.splitlines() if l.strip()), ""
        )
        normalized = re.sub(r"^-+\s*", "", first_line).upper()

        base = {
            "form_a_written": form_a_lean.exists() and form_a_lean.stat().st_size > 0,
            "form_b_written": form_b_lean.exists() and form_b_lean.stat().st_size > 0,
            "form_a_compiled": None,
            "form_b_compiled": None,
            "proof_compiled": None,
            "milp_reform_found": None,
            "sorry_free": None,
        }

        if normalized.startswith("NOT REFORMULATION"):
            return {
                "is_reformulation": False,
                "agent_decision": "not_reformulation",
                "agent_reason": reform_content,
                **base,
            }

        if normalized.startswith("MCP_UNAVAILABLE"):
            return {
                "is_reformulation": False,
                "agent_decision": "mcp_unavailable",
                "agent_reason": reform_content,
                **base,
            }

        form_a_written = base["form_a_written"]
        form_b_written = base["form_b_written"]
        proof_written = bool(reform_content)

        # Compile signals come from the container entrypoint: it ran
        # `lake env lean` on A/B/Reformulation and wrote result.json +
        # compile_log.txt back through the bind mount.
        result_path = artifacts_dir / "result.json"
        compile_log_path = artifacts_dir / "compile_log.txt"
        entry_result: dict = {}
        if result_path.exists():
            try:
                entry_result = json.loads(result_path.read_text())
            except json.JSONDecodeError:
                entry_result = {}
        compile_log = compile_log_path.read_text() if compile_log_path.exists() else ""

        form_a_compiled = (
            form_a_written and entry_result.get("form_a_compile_exit") == 0
        )
        form_b_compiled = (
            form_b_written and entry_result.get("form_b_compile_exit") == 0
        )
        proof_compiled = (
            proof_written and entry_result.get("compile_exit") == 0
        )

        milp_reform_found = bool(
            re.search(r"\bdef\s+\w+\s*:\s*MILPReformulation\b", reform_content)
        )
        # Lean emits "warning: 'X' uses sorry" when sorry is present.
        # Only meaningful when the proof compiled and the def was found.
        sorry_free = (
            "uses `sorry`" not in compile_log
            if (proof_compiled and milp_reform_found)
            else False
        )

        is_reformulation = (
            form_a_compiled
            and form_b_compiled
            and proof_compiled
            and milp_reform_found
            and sorry_free
        )

        return {
            "is_reformulation": is_reformulation,
            "agent_decision": "reformulation" if is_reformulation else "failed",
            "form_a_written": form_a_written,
            "form_b_written": form_b_written,
            "form_a_compiled": form_a_compiled,
            "form_b_compiled": form_b_compiled,
            "proof_compiled": proof_compiled,
            "milp_reform_found": milp_reform_found,
            "sorry_free": sorry_free,
        }
