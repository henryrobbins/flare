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
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from threading import Lock
from typing import Any

import yaml
from dotenv import load_dotenv

load_dotenv()

from formulation_bench import Dataset, Pair  # noqa: E402

from experiments.utils import (  # noqa: E402
    add_common_args,
    drain_with_interrupt,
    filter_pairs,
    make_run_dir,
    pair_id,
    resolve_problem_filter,
    run_verification,
    write_and_log,
)
from src.verify.base import ReformulationVerifier  # noqa: E402
from src.verify.factory import build_verifier  # noqa: E402

DEFAULT_CONFIG = Path(__file__).parent / "configs" / "baseline.yaml"


@dataclass
class VerifierEntry:
    verifier: ReformulationVerifier
    name: str
    multi_run: bool


def process_task(
    pair: Pair,
    entry: VerifierEntry,
    run_idx: int | None,
    results_path: Path,
    write_lock: Lock,
) -> None:
    pid = pair_id(pair.a, pair.b)
    artifacts_base = results_path.parent / "pairs" / pid / entry.name
    artifacts_dir = (
        artifacts_base / str(run_idx) if run_idx is not None else artifacts_base
    )
    row = run_verification(entry.verifier, pair, artifacts_dir, entry.name, run_idx)
    write_and_log(
        row, results_path, write_lock, entry.name, run_idx, pair.reformulation
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser, DEFAULT_CONFIG)
    args = parser.parse_args()

    cfg = yaml.safe_load(args.config.read_text())
    workers = args.workers if args.workers is not None else cfg.get("workers", 5)
    runs = args.runs if args.runs is not None else cfg.get("runs", 3)
    problem_filter = resolve_problem_filter(args.problems, cfg)

    run_dir = make_run_dir()
    dataset = Dataset(Path("dataset"))

    entries: list[VerifierEntry] = []
    seen_names: set[str] = set()
    for spec in cfg["verifiers"]:
        spec = dict(spec)
        multi_run = bool(spec.pop("multi_run", False))
        name_override = spec.pop("name", None)
        verifier = build_verifier(spec)
        name = name_override or verifier.name
        if name in seen_names:
            raise ValueError(
                f"duplicate verifier name {name!r}; set a unique `name:` in YAML"
            )
        seen_names.add(name)
        entries.append(VerifierEntry(verifier=verifier, name=name, multi_run=multi_run))

    pairs = filter_pairs(dataset.pairs, problem_filter)
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

    executor = ThreadPoolExecutor(max_workers=workers)
    futures = {
        executor.submit(process_task, pair, entry, run_idx, results_path, write_lock): (
            pair,
            entry,
            run_idx,
        )
        for pair, entry, run_idx in tasks
    }

    def on_result(future: Future[Any]) -> None:
        exc = future.exception()
        if exc:
            pair, entry, run_idx = futures[future]
            pid = pair_id(pair.a, pair.b)
            suffix = f"#{run_idx}" if run_idx is not None else ""
            print(f"  FATAL [{entry.name}{suffix}] [{pid}]: {exc}")

    try:
        drain_with_interrupt(executor, futures, run_dir.name, on_result)
    finally:
        executor.shutdown(wait=True)


if __name__ == "__main__":
    main()
