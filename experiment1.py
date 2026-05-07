"""
experiment1.py — run all reformulation checkers on every pair in dataset/pairs.json.

Each invocation creates a fresh timestamped subdirectory under runs/, e.g.
runs/20260424T093000Z/. Results stream to results.jsonl inside that directory;
intermediate artifacts land in pairs/{pair_id}/{method}/ alongside it.

Pairs are processed in parallel (default: 10 at a time).
"""

import argparse
import json
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

from dotenv import load_dotenv

load_dotenv()

from milp_eq_tools import Dataset, Formulation, Pair

from src.llm_client import OpenAIClient, LLMConfig
from src.verify.base import ReformulationVerifier
from src.verify.equivamap.equivamap import EquivaMapVerifier
from src.verify.flare.flare import FLAREVerifier
from src.verify.execution.execution import ExecutionVerifier
from src.verify.llm.llm import LLMVerifier

DEFAULT_WORKERS = 5


def parse_problem_ids(s: str | None) -> set[int] | None:
    if s is None:
        return None
    return {int(x.strip()) for x in s.split(",")}


def pair_id(a: Formulation, b: Formulation) -> str:
    def parts(f: Formulation) -> tuple[str, str]:
        problem = f.path.parent.parent.name  # "p1"
        formulation = f.path.name  # "a"
        return problem, formulation

    pa, fa = parts(a)
    pb, fb = parts(b)
    return f"{pa}_{fa}__{pb}_{fb}"


def process_pair(
    pair: Pair,
    checkers: list[ReformulationVerifier],
    results_path: Path,
    write_lock: Lock,
) -> None:
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
            "ground_truth": pair.reformulation,
            "method": checker.name,
            "is_reformulation": None,
            "duration_s": None,
            "cost_usd": None,
            "artifacts_dir": None,
            "error": None,
        }
        try:
            result = checker.verify(
                pair.a, pair.b, results_path.parent / "pairs" / pid / checker.name
            )
            entry["is_reformulation"] = result.is_reformulation
            entry["duration_s"] = result.duration_s
            entry["cost_usd"] = result.cost_usd
            entry["artifacts_dir"] = str(result.artifacts_dir.relative_to(Path(".")))
        except Exception:
            entry["error"] = traceback.format_exc()

        with write_lock:
            with results_path.open("a") as f:
                f.write(json.dumps(entry) + "\n")

            status = "✓" if entry["error"] is None else "✗"
            equiv = entry["is_reformulation"]
            gt = pair.reformulation
            match = equiv == gt if equiv is not None else None
            if entry["error"]:
                print(f"  {status} [{checker.name}] {pid}\n{entry['error']}")
            else:
                print(
                    f"  {status} [{checker.name}] {pid}  equiv={equiv}  gt={gt}  correct={match}"
                )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--problems",
        "-p",
        help="comma-separated problem numbers to run (e.g. 1,2,3; default: all)",
    )
    parser.add_argument(
        "--workers",
        "-w",
        type=int,
        default=DEFAULT_WORKERS,
        help=f"parallel workers (default: {DEFAULT_WORKERS})",
    )
    args = parser.parse_args()

    problem_filter = parse_problem_ids(args.problems)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = Path("runs") / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    dataset = Dataset(Path("dataset"))

    checkers: list[ReformulationVerifier] = [
        ExecutionVerifier(),
        EquivaMapVerifier(OpenAIClient(LLMConfig(model="gpt-4.1", max_tokens=4096))),
        FLAREVerifier(repo_root=Path(".").resolve(), model="claude-opus-4-7"),
    ]

    pairs = dataset.pairs
    if problem_filter is not None:
        pairs = [
            p
            for p in pairs
            if (
                int(p.a.path.parent.parent.name.lstrip("p")) in problem_filter
                or int(p.b.path.parent.parent.name.lstrip("p")) in problem_filter
            )
        ]

    results_path = run_dir / "results.jsonl"
    write_lock = Lock()

    print(f"Run directory: {run_dir}")
    print(f"Pairs: {len(pairs)}  Workers: {args.workers}\n")

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {
            executor.submit(
                process_pair, pair, checkers, results_path, write_lock
            ): pair
            for pair in pairs
        }
        for future in as_completed(futures):
            exc = future.exception()
            if exc:
                pair = futures[future]
                pid = pair_id(pair.a, pair.b)
                print(f"  FATAL [{pid}]: {exc}")


if __name__ == "__main__":
    main()
