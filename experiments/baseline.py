"""
baseline.py — run baseline reformulation verifiers on every pair.

Combines the previous experiment1 (single-run) and experiment3 (multi-run)
into one script. Per-verifier `multi_run` in the YAML config decides whether
that verifier is run once (flat artifacts dir, `run` = null in results) or
N times with `--runs` (artifacts under {verifier_name}/{run}/).

Each invocation creates a fresh timestamped subdirectory under runs/. Results
stream to results.jsonl inside that directory; intermediate artifacts land
under pairs/{pair_id}/{verifier_name}[/{run}]/ alongside it.
"""

import argparse
import json
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

import yaml
from dotenv import load_dotenv

load_dotenv()

from formulation_bench import Dataset, Formulation, Pair

from src.verify.base import ReformulationVerifier
from src.verify.factory import build_verifier

DEFAULT_CONFIG = Path(__file__).parent / "configs" / "baseline.yaml"


@dataclass
class VerifierEntry:
    verifier: ReformulationVerifier
    name: str
    multi_run: bool


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


def process_task(
    pair: Pair,
    entry: VerifierEntry,
    run_idx: int | None,
    results_path: Path,
    write_lock: Lock,
) -> None:
    pid = pair_id(pair.a, pair.b)
    pa, fa = pid.split("__")[0].split("_", 1)
    pb, fb = pid.split("__")[1].split("_", 1)

    artifacts_base = results_path.parent / "pairs" / pid / entry.name
    artifacts_dir = artifacts_base / str(run_idx) if run_idx is not None else artifacts_base

    row: dict = {
        "pair_id": pid,
        "problem_a": pa,
        "formulation_a": fa,
        "problem_b": pb,
        "formulation_b": fb,
        "ground_truth": pair.reformulation,
        "method": entry.name,
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
        result = entry.verifier.verify(pair.a, pair.b, artifacts_dir)
        row["is_reformulation"] = result.is_reformulation
        row["duration_s"] = result.duration_s
        row["cost_usd"] = result.cost_usd
        row["input_tokens"] = result.metadata.get("input_tokens")
        row["output_tokens"] = result.metadata.get("output_tokens")
        row["reasoning_tokens"] = result.metadata.get("reasoning_tokens")
        row["artifacts_dir"] = str(result.artifacts_dir.relative_to(Path(".")))
    except Exception:
        row["error"] = traceback.format_exc()

    with write_lock:
        with results_path.open("a") as f:
            f.write(json.dumps(row) + "\n")

        status = "✓" if row["error"] is None else "✗"
        equiv = row["is_reformulation"]
        gt = pair.reformulation
        match = equiv == gt if equiv is not None else None
        suffix = f"#{run_idx}" if run_idx is not None else ""
        tag = f"[{entry.name}{suffix}] {pid}"
        if row["error"]:
            print(f"  {status} {tag}\n{row['error']}")
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
        help="runs per (pair, multi_run verifier) (overrides YAML)",
    )
    args = parser.parse_args()

    cfg = yaml.safe_load(args.config.read_text())
    workers = args.workers if args.workers is not None else cfg.get("workers", 5)
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

    repo_root = Path(".").resolve()
    entries: list[VerifierEntry] = []
    seen_names: set[str] = set()
    for spec in cfg["verifiers"]:
        spec = dict(spec)
        multi_run = bool(spec.pop("multi_run", False))
        name_override = spec.pop("name", None)
        verifier = build_verifier(spec, repo_root=repo_root)
        name = name_override or verifier.name
        if name in seen_names:
            raise ValueError(
                f"duplicate verifier name {name!r}; set a unique `name:` in YAML"
            )
        seen_names.add(name)
        entries.append(VerifierEntry(verifier=verifier, name=name, multi_run=multi_run))

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

    n_multi = sum(1 for e in entries if e.multi_run)
    n_single = len(entries) - n_multi
    print(f"Run directory: {run_dir}")
    print(f"Config: {args.config}")
    print(
        f"Pairs: {len(pairs)}  Verifiers: {len(entries)} "
        f"({n_single} single, {n_multi} multi×{runs})  Workers: {workers}\n"
    )

    tasks: list[tuple[Pair, VerifierEntry, int | None]] = []
    for pair in pairs:
        for entry in entries:
            if entry.multi_run:
                for run_idx in range(1, runs + 1):
                    tasks.append((pair, entry, run_idx))
            else:
                tasks.append((pair, entry, None))

    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(
                process_task, pair, entry, run_idx, results_path, write_lock
            ): (pair, entry, run_idx)
            for pair, entry, run_idx in tasks
        }
        for future in as_completed(futures):
            exc = future.exception()
            if exc:
                pair, entry, run_idx = futures[future]
                pid = pair_id(pair.a, pair.b)
                suffix = f"#{run_idx}" if run_idx is not None else ""
                print(f"  FATAL [{entry.name}{suffix}] [{pid}]: {exc}")


if __name__ == "__main__":
    main()
