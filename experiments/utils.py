"""Shared helpers for experiment scripts (baseline.py, ablation.py)."""

import argparse
import json
import traceback
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock

from formulation_bench import Formulation, Pair

from src.verify.base import ReformulationVerifier


def pair_id(a: Formulation, b: Formulation) -> str:
    def parts(f: Formulation) -> tuple[str, str]:
        problem = f.path.parent.parent.name  # "p1"
        formulation = f.path.name  # "a"
        return problem, formulation

    pa, fa = parts(a)
    pb, fb = parts(b)
    return f"{pa}_{fa}__{pb}_{fb}"


def parse_problem_ids(s: str | None) -> set[int] | None:
    if s is None:
        return None
    return {int(x.strip()) for x in s.split(",")}


def resolve_problem_filter(
    cli_problems: str | None, cfg: dict
) -> set[int] | None:
    """CLI --problems wins; falls back to YAML `problems:`; else no filter."""
    if cli_problems is not None:
        return parse_problem_ids(cli_problems)
    if "problems" in cfg:
        return set(cfg["problems"])
    return None


def filter_pairs(pairs: list[Pair], problem_filter: set[int] | None) -> list[Pair]:
    if problem_filter is None:
        return list(pairs)
    return [
        p
        for p in pairs
        if (
            int(p.a.path.parent.parent.name.lstrip("p")) in problem_filter
            or int(p.b.path.parent.parent.name.lstrip("p")) in problem_filter
        )
    ]


def make_run_dir() -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = Path("runs") / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)
    return run_dir


def add_common_args(parser: argparse.ArgumentParser, default_config: Path) -> None:
    """Add the --config / --problems / --workers / --runs flags shared by all
    experiment scripts."""
    parser.add_argument(
        "--config",
        "-c",
        type=Path,
        default=default_config,
        help=f"YAML config (default: {default_config})",
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
        help="runs per (pair, multi-run verifier) (overrides YAML)",
    )


def run_verification(
    verifier: ReformulationVerifier,
    pair: Pair,
    artifacts_dir: Path,
    name: str,
    run_idx: int | None,
) -> dict:
    """Verify one pair, returning a result row dict (errors captured into row['error'])."""
    pid = pair_id(pair.a, pair.b)
    pa, fa = pid.split("__")[0].split("_", 1)
    pb, fb = pid.split("__")[1].split("_", 1)

    row: dict = {
        "pair_id": pid,
        "problem_a": pa,
        "formulation_a": fa,
        "problem_b": pb,
        "formulation_b": fb,
        "ground_truth": pair.reformulation,
        "method": name,
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
        result = verifier.verify(pair.a, pair.b, artifacts_dir)
        row["is_reformulation"] = result.is_reformulation
        row["duration_s"] = result.duration_s
        row["cost_usd"] = result.cost_usd
        row["input_tokens"] = result.metadata.get("input_tokens")
        row["output_tokens"] = result.metadata.get("output_tokens")
        row["reasoning_tokens"] = result.metadata.get("reasoning_tokens")
        row["artifacts_dir"] = str(result.artifacts_dir.relative_to(Path(".")))
    except Exception:
        row["error"] = traceback.format_exc()
    return row


def write_and_log(
    row: dict,
    results_path: Path,
    write_lock: Lock,
    name: str,
    run_idx: int | None,
    gt: bool,
) -> None:
    """Append the row to results.jsonl and print a one-line status."""
    suffix = f"#{run_idx}" if run_idx is not None else ""
    tag = f"[{name}{suffix}] {row['pair_id']}"
    with write_lock:
        with results_path.open("a") as f:
            f.write(json.dumps(row) + "\n")
        status = "✓" if row["error"] is None else "✗"
        equiv = row["is_reformulation"]
        match = equiv == gt if equiv is not None else None
        if row["error"]:
            print(f"  {status} {tag}\n{row['error']}")
        else:
            print(f"  {status} {tag}  equiv={equiv}  gt={gt}  correct={match}")
