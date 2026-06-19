"""Shared helpers for experiment scripts (baseline.py, ablation.py)."""

import argparse
import json
import os
import subprocess
import traceback
from collections.abc import Callable, Iterable
from concurrent.futures import Future, ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from threading import Lock
from typing import Any

from formulation_bench import Formulation, Reformulation

from src.verify.base import ReformulationRun, ReformulationVerifier


class RunRegistry:
    """Thread-safe set of in-flight :class:`ReformulationRun` handles."""

    def __init__(self) -> None:
        self._lock = Lock()
        self._runs: set[ReformulationRun] = set()

    def add(self, run: ReformulationRun) -> None:
        with self._lock:
            self._runs.add(run)

    def remove(self, run: ReformulationRun) -> None:
        with self._lock:
            self._runs.discard(run)

    def cancel_all(self) -> None:
        with self._lock:
            runs = list(self._runs)
        for run in runs:
            try:
                run.cancel()
            except Exception:
                pass


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
    cli_problems: str | None, cfg: dict[str, Any]
) -> set[int] | None:
    """CLI --problems wins; falls back to YAML `problems:`; else no filter."""
    if cli_problems is not None:
        return parse_problem_ids(cli_problems)
    if "problems" in cfg:
        return set(cfg["problems"])
    return None


def filter_pairs(
    pairs: list[Reformulation], problem_filter: set[int] | None
) -> list[Reformulation]:
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
    # Tag every container spawned during this run so we can kill them on
    # Ctrl+C (see kill_run_containers / run_with_interrupt).
    os.environ["FLARE_RUN_ID"] = timestamp
    return run_dir


def kill_run_containers(run_id: str) -> None:
    """`docker kill` every container labeled flare-run=<run_id>."""
    try:
        out = subprocess.run(
            ["docker", "ps", "-q", "--filter", f"label=flare-run={run_id}"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return
    ids = out.stdout.split()
    if not ids:
        return
    print(f"  Stopping {len(ids)} container(s)...")
    subprocess.run(["docker", "kill", *ids], check=False, capture_output=True)


def kill_run_sandboxes(run_id: str) -> None:
    """`terminate` every Modal Sandbox tagged flare-run=<run_id>."""
    try:
        import modal
    except ModuleNotFoundError:
        return
    try:
        sandboxes = list(modal.Sandbox.list(tags={"flare-run": run_id}))
    except Exception:
        return
    if not sandboxes:
        return
    print(f"  Stopping {len(sandboxes)} sandbox(es)...")
    for sb in sandboxes:
        try:
            sb.terminate()
        except Exception:
            pass


def drain_with_interrupt(
    executor: ThreadPoolExecutor,
    futures: Iterable[Future[Any]],
    run_id: str,
    on_result: Callable[[Future[Any]], None],
    registry: RunRegistry,
) -> None:
    """Iterate through the task futures, calling `on_result` as each completed.

    On KeyboardInterrupt, cancel in-flight runs, drain the executor, then sweep
    any leaked containers / Modal Sandboxes.
    """
    futures = list(futures)
    try:
        for future in as_completed(futures):
            on_result(future)
    except KeyboardInterrupt:
        print("\n  Interrupted. Cancelling in-flight runs and shutting down...")
        # Cancel each in-flight run (captures partial artifacts and tears down)
        registry.cancel_all()
        for f in futures:
            f.cancel()
        # wait=True drains the now-canceled workers promptly.
        executor.shutdown(wait=True, cancel_futures=True)
        # Backstops: reap any container/Sandbox the cooperative path left behind
        kill_run_containers(run_id)
        kill_run_sandboxes(run_id)
        raise SystemExit(130)


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
    pair: Reformulation,
    artifacts_dir: Path,
    name: str,
    run_idx: int | None,
    registry: RunRegistry,
    model: str | None = None,
    mode: str | None = None,
) -> dict[str, Any]:
    """Verify one pair, returning a row dict (errors captured in row['error'])."""
    pid = pair_id(pair.a, pair.b)
    pa, fa = pid.split("__")[0].split("_", 1)
    pb, fb = pid.split("__")[1].split("_", 1)

    row: dict[str, Any] = {
        "pair_id": pid,
        "problem_a": pa,
        "formulation_a": fa,
        "problem_b": pb,
        "formulation_b": fb,
        "ground_truth": pair.is_reformulation,
        "method": name,
        "model": model,
        "mode": mode,
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
        run = verifier.start(pair.a, pair.b, artifacts_dir)
        registry.add(run)
        try:
            result = run.result()
        finally:
            registry.remove(run)
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
    row: dict[str, Any],
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
