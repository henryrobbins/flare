"""
ablation.py — LLM-judge ablation across (model × prompt mode), with
multiple runs per (pair, verifier) to estimate variance.

Each invocation creates a fresh timestamped subdirectory under runs/, e.g.
runs/20260424T093000Z/. Results stream to results.jsonl inside that directory;
intermediate artifacts land in pairs/{pair_id}/{method}/{run}/ alongside it.

Verifier configuration is loaded from a YAML file (default:
experiments/configs/ablation.yaml). CLI flags override YAML values.
"""

import argparse
from concurrent.futures import Future, ThreadPoolExecutor
from pathlib import Path
from threading import Lock
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

DEFAULT_CONFIG = Path(__file__).parent / "configs" / "ablation.yaml"


def process_pair_verifier(
    pair: Reformulation,
    verifier: ReformulationVerifier,
    model: str,
    mode: str,
    run_idx: int,
    results_path: Path,
    write_lock: Lock,
    registry: RunRegistry,
) -> None:
    pid = pair_id(pair.a, pair.b)
    artifacts_dir = results_path.parent / "pairs" / pid / verifier.name / str(run_idx)
    row = run_verification(
        verifier,
        pair,
        artifacts_dir,
        verifier.name,
        run_idx,
        registry,
        model=model,
        mode=mode,
    )
    write_and_log(
        row, results_path, write_lock, verifier.name, run_idx, pair.is_reformulation
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser, DEFAULT_CONFIG)
    args = parser.parse_args()

    cfg = yaml.safe_load(args.config.read_text())
    workers = args.workers if args.workers is not None else cfg.get("workers", 25)
    runs = args.runs if args.runs is not None else cfg.get("runs", 3)
    problem_filter = resolve_problem_filter(args.problems, cfg)

    run_dir = make_run_dir()
    dataset = Dataset(Path("dataset"))

    # Expand the (models × modes) cross product into llm verifier specs.
    verifiers: list[tuple[ReformulationVerifier, str, str]] = []
    for model in cfg["models"]:
        for mode in cfg["modes"]:
            spec = {
                "type": "llm",
                "name": f"llm_{model['label']}_{mode['label']}",
                "client": model["client"],
                "template": mode["template"],
                "include_implicit": mode["include_implicit"],
            }
            verifiers.append(
                (
                    build_verifier(spec),
                    model["label"],
                    mode["label"],
                )
            )

    pairs = filter_pairs(dataset.reformulations, problem_filter)
    results_path = run_dir / "results.jsonl"
    write_lock = Lock()

    print(f"Run directory: {run_dir}")
    print(f"Config: {args.config}")
    print(
        f"Pairs: {len(pairs)}  Verifiers: {len(verifiers)}  Runs: {runs}  "
        f"Workers: {workers}\n"
    )

    tasks = [
        (pair, verifier, model, mode, run_idx)
        for pair in pairs
        for verifier, model, mode in verifiers
        for run_idx in range(1, runs + 1)
    ]

    registry = RunRegistry()
    executor = ThreadPoolExecutor(max_workers=workers)
    futures = {
        executor.submit(
            process_pair_verifier,
            pair,
            verifier,
            model,
            mode,
            run_idx,
            results_path,
            write_lock,
            registry,
        ): (pair, verifier, run_idx)
        for pair, verifier, model, mode, run_idx in tasks
    }

    def on_result(future: Future[Any]) -> None:
        exc = future.exception()
        if exc:
            pair, verifier, run_idx = futures[future]
            pid = pair_id(pair.a, pair.b)
            print(f"  FATAL [{verifier.name}#{run_idx}] [{pid}]: {exc}")

    try:
        drain_with_interrupt(
            executor, futures, run_dir.name, on_result, registry=registry
        )
    finally:
        executor.shutdown(wait=True)


if __name__ == "__main__":
    main()
