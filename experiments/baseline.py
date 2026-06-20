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
import contextlib
from collections.abc import Iterator
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from threading import BoundedSemaphore, Lock
from typing import Any

import yaml
from dotenv import load_dotenv

load_dotenv()

from formulation_bench import Dataset, Reformulation  # noqa: E402

from experiments.utils import (  # noqa: E402
    RunRegistry,
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
    # Per-harness concurrency gate; None means unlimited. Verifiers sharing a
    # harness (keyed by harness type) share one semaphore so e.g. claude_code's
    # account-level concurrent-session limit is respected across verifiers.
    sem: BoundedSemaphore | None = None


@contextlib.contextmanager
def _maybe_acquire(sem: BoundedSemaphore | None) -> Iterator[None]:
    """Hold `sem` for the duration of the block, or do nothing if `sem` is None."""
    if sem is None:
        yield
        return
    with sem:
        yield


def process_task(
    pair: Reformulation,
    entry: VerifierEntry,
    run_idx: int | None,
    results_path: Path,
    write_lock: Lock,
    registry: RunRegistry,
) -> None:
    pid = pair_id(pair.a, pair.b)
    artifacts_base = results_path.parent / "pairs" / pid / entry.name
    artifacts_dir = (
        artifacts_base / str(run_idx) if run_idx is not None else artifacts_base
    )
    with _maybe_acquire(entry.sem):
        row = run_verification(
            entry.verifier, pair, artifacts_dir, entry.name, run_idx, registry=registry
        )
    write_and_log(
        row, results_path, write_lock, entry.name, run_idx, pair.is_reformulation
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

    # Per-harness concurrency caps: {harness_name: max_concurrent}. Verifiers
    # sharing a harness type share one semaphore (e.g. to respect claude_code's
    # account-level concurrent-session limit even when `workers` is higher).
    concurrency: dict[str, int] = dict(cfg.get("concurrency", {}))
    semaphores = {key: BoundedSemaphore(limit) for key, limit in concurrency.items()}

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
        # Key the concurrency gate on harness type when the verifier exposes one
        # (FLARE verifiers report it via get_config_dict); else on verifier name.
        harness_key = verifier.get_config_dict().get("harness", verifier.name)
        entries.append(
            VerifierEntry(
                verifier=verifier,
                name=name,
                multi_run=multi_run,
                sem=semaphores.get(harness_key),
            )
        )

    pairs = filter_pairs(dataset.reformulations, problem_filter)
    results_path = run_dir / "results.jsonl"
    write_lock = Lock()

    n_multi = sum(1 for e in entries if e.multi_run)
    n_single = len(entries) - n_multi
    print(f"Run directory: {run_dir}")
    print(f"Config: {args.config}")
    print(
        f"Pairs: {len(pairs)}  Verifiers: {len(entries)} "
        f"({n_single} single, {n_multi} multi×{runs})  Workers: {workers}"
    )
    if concurrency:
        caps = ", ".join(f"{k}={v}" for k, v in concurrency.items())
        print(f"Per-harness concurrency caps: {caps}")
    print()

    tasks: list[tuple[Reformulation, VerifierEntry, int | None]] = []
    for pair in pairs:
        for entry in entries:
            if entry.multi_run:
                for run_idx in range(1, runs + 1):
                    tasks.append((pair, entry, run_idx))
            else:
                tasks.append((pair, entry, None))

    registry = RunRegistry()
    executor = ThreadPoolExecutor(max_workers=workers)
    futures = {
        executor.submit(
            process_task, pair, entry, run_idx, results_path, write_lock, registry
        ): (
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
        drain_with_interrupt(
            executor, futures, run_dir.name, on_result, registry=registry
        )
    finally:
        executor.shutdown(wait=True)


if __name__ == "__main__":
    main()
