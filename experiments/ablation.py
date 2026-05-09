"""
ablation.py — LLM-judge ablation across (model × prompt mode), with
multiple runs per (pair, checker) to estimate variance.

Each invocation creates a fresh timestamped subdirectory under runs/, e.g.
runs/20260424T093000Z/. Results stream to results.jsonl inside that directory;
intermediate artifacts land in pairs/{pair_id}/{method}/{run}/ alongside it.

Checker configuration is loaded from a YAML file (default:
experiments/configs/ablation.yaml). CLI flags override YAML values.
"""

import argparse
import json
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

import yaml
from dotenv import load_dotenv

load_dotenv()

from formulation_bench import Dataset, Formulation, Pair

from src.verify.base import ReformulationVerifier
from src.verify.factory import build_verifier

DEFAULT_CONFIG = Path(__file__).parent / "configs" / "ablation.yaml"


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


def process_pair_checker(
    pair: Pair,
    checker: ReformulationVerifier,
    run_idx: int,
    results_path: Path,
    write_lock: Lock,
) -> None:
    pid = pair_id(pair.a, pair.b)
    pa, fa = pid.split("__")[0].split("_", 1)
    pb, fb = pid.split("__")[1].split("_", 1)

    entry: dict = {
        "pair_id": pid,
        "problem_a": pa,
        "formulation_a": fa,
        "problem_b": pb,
        "formulation_b": fb,
        "ground_truth": pair.reformulation,
        "method": checker.name,
        "run": run_idx,
        "is_reformulation": None,
        "duration_s": None,
        "cost_usd": None,
        "input_tokens": None,
        "output_tokens": None,
        "reasoning_tokens": None,
        "artifacts_dir": None,
        "error": None,
    }
    try:
        result = checker.verify(
            pair.a,
            pair.b,
            results_path.parent / "pairs" / pid / checker.name / str(run_idx),
        )
        entry["is_reformulation"] = result.is_reformulation
        entry["duration_s"] = result.duration_s
        entry["cost_usd"] = result.cost_usd
        entry["input_tokens"] = result.metadata.get("input_tokens")
        entry["output_tokens"] = result.metadata.get("output_tokens")
        entry["reasoning_tokens"] = result.metadata.get("reasoning_tokens")
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
        tag = f"[{checker.name}#{run_idx}] {pid}"
        if entry["error"]:
            print(f"  {status} {tag}\n{entry['error']}")
        else:
            print(f"  {status} {tag}  equiv={equiv}  gt={gt}  correct={match}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        "-c",
        type=Path,
        default=DEFAULT_CONFIG,
        help=f"YAML config (default: {DEFAULT_CONFIG})",
    )
    parser.add_argument(
        "--problems",
        "-p",
        help="comma-separated problem numbers to run (e.g. 1,2,3; default: all)",
    )
    parser.add_argument(
        "--workers",
        "-w",
        type=int,
        default=None,
        help="parallel workers (overrides YAML)",
    )
    parser.add_argument(
        "-n",
        "--runs",
        type=int,
        default=None,
        help="number of runs per (pair, checker) (overrides YAML)",
    )
    args = parser.parse_args()

    cfg = yaml.safe_load(args.config.read_text())
    workers = args.workers if args.workers is not None else cfg.get("workers", 25)
    runs = args.runs if args.runs is not None else cfg.get("runs", 3)

    if args.problems is not None:
        problem_filter = parse_problem_ids(args.problems)
    elif "problems" in cfg:
        problem_filter = set(cfg["problems"])
    else:
        problem_filter = None

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = Path("runs") / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    dataset = Dataset(Path("dataset"))

    # Expand the (models × modes) cross product into llm verifier specs.
    checker_specs = [
        {
            "type": "llm",
            "name": f"llm_{model['label']}_{mode['label']}",
            "client": model["client"],
            "template": mode["template"],
            "include_implicit": mode["include_implicit"],
        }
        for model in cfg["models"]
        for mode in cfg["modes"]
    ]
    repo_root = Path(".").resolve()
    checkers: list[ReformulationVerifier] = [
        build_verifier(spec, repo_root=repo_root) for spec in checker_specs
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
    print(f"Config: {args.config}")
    print(
        f"Pairs: {len(pairs)}  Checkers: {len(checkers)}  Runs: {runs}  "
        f"Workers: {workers}\n"
    )

    tasks = [
        (pair, checker, run_idx)
        for pair in pairs
        for checker in checkers
        for run_idx in range(1, runs + 1)
    ]

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(
                process_pair_checker,
                pair,
                checker,
                run_idx,
                results_path,
                write_lock,
            ): (pair, checker, run_idx)
            for pair, checker, run_idx in tasks
        }
        for future in as_completed(futures):
            exc = future.exception()
            if exc:
                pair, checker, run_idx = futures[future]
                pid = pair_id(pair.a, pair.b)
                print(f"  FATAL [{checker.name}#{run_idx}] [{pid}]: {exc}")


if __name__ == "__main__":
    main()
