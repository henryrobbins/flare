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
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from threading import Lock

import yaml
from dotenv import load_dotenv

load_dotenv()

from formulation_bench import Dataset, Pair

from experiments.utils import (
    add_common_args,
    filter_pairs,
    make_run_dir,
    pair_id,
    resolve_problem_filter,
    run_verification,
    write_and_log,
)
from src.verify.base import ReformulationVerifier
from src.verify.factory import build_verifier

DEFAULT_CONFIG = Path(__file__).parent / "configs" / "ablation.yaml"


def process_pair_verifier(
    pair: Pair,
    verifier: ReformulationVerifier,
    model: str,
    mode: str,
    run_idx: int,
    results_path: Path,
    write_lock: Lock,
) -> None:
    pid = pair_id(pair.a, pair.b)
    artifacts_dir = (
        results_path.parent / "pairs" / pid / verifier.name / str(run_idx)
    )
    row = run_verification(
        verifier, pair, artifacts_dir, verifier.name, run_idx,
        model=model, mode=mode,
    )
    write_and_log(
        row, results_path, write_lock, verifier.name, run_idx, pair.reformulation
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
    repo_root = Path(".").resolve()
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
                (build_verifier(spec, repo_root=repo_root), model["label"], mode["label"])
            )

    pairs = filter_pairs(dataset.pairs, problem_filter)
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

    with ThreadPoolExecutor(max_workers=workers) as executor:
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
            ): (pair, verifier, run_idx)
            for pair, verifier, model, mode, run_idx in tasks
        }
        for future in as_completed(futures):
            exc = future.exception()
            if exc:
                pair, verifier, run_idx = futures[future]
                pid = pair_id(pair.a, pair.b)
                print(f"  FATAL [{verifier.name}#{run_idx}] [{pid}]: {exc}")


if __name__ == "__main__":
    main()
