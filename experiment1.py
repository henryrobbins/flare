"""
experiment1.py — run all equivalence checkers on every pair in dataset/pairs.json.

Results are written to runs/results.jsonl (one JSON object per line).
Intermediate artifacts for each checker land in runs/pairs/{pair_id}/{method}/.
"""

import json
import traceback
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

from milp_eq_tools import Dataset, Formulation

from src.execution_checker import ExecutionChecker
from src.llm_client import AnthropicClient
from src.naive_llm_checker import NaiveLLMChecker


def pair_id(a: Formulation, b: Formulation) -> str:
    # path: .../problems/pN/formulations/X
    def parts(f: Formulation) -> tuple[str, str]:
        problem = f.path.parent.parent.name  # "p1"
        formulation = f.path.name            # "a"
        return problem, formulation

    pa, fa = parts(a)
    pb, fb = parts(b)
    return f"{pa}_{fa}__{pb}_{fb}"


def main() -> None:
    runs_dir = Path("runs")
    runs_dir.mkdir(exist_ok=True)

    dataset = Dataset(Path("dataset"))
    client = AnthropicClient()

    checkers = [
        ExecutionChecker(runs_dir),
        NaiveLLMChecker(runs_dir, client),
    ]

    results_path = runs_dir / "results.jsonl"

    for pair in dataset.pairs:
        pid = pair_id(pair.a, pair.b)
        pa, fa = pid.split("__")[0].split("_", 1)
        pb, fb = pid.split("__")[1].split("_", 1)

        for checker in checkers:
            entry: dict = {
                "pair_id": pid,
                "problem_a": pa,
                "formulation_a": fa,
                "problem_b": pb,
                "formulation_b": fb,
                "ground_truth": pair.equivalent,
                "method": checker.name,
                "is_equivalent": None,
                "artifacts_dir": None,
                "error": None,
            }
            try:
                result = checker.check(pair.a, pair.b, pid)
                entry["is_equivalent"] = result.is_equivalent
                entry["artifacts_dir"] = str(result.artifacts_dir.relative_to(Path(".")))
            except Exception:
                entry["error"] = traceback.format_exc()
                print(f"  ERROR [{checker.name}] {pid}:\n{entry['error']}")

            with results_path.open("a") as f:
                f.write(json.dumps(entry) + "\n")

            status = "✓" if entry["error"] is None else "✗"
            equiv = entry["is_equivalent"]
            gt = pair.equivalent
            match = equiv == gt if equiv is not None else None
            print(f"  {status} [{checker.name}] {pid}  equiv={equiv}  gt={gt}  correct={match}")


if __name__ == "__main__":
    main()
