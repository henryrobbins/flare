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

from formulation_bench import Dataset, Formulation, Pair

from src.llm_client import (
    AnthropicClient,
    DeepSeekClient,
    LLMClient,
    LLMConfig,
    OpenAIClient,
)
from src.verify.base import ReformulationVerifier
from src.verify.llm.llm import LLMVerifier

DEFAULT_WORKERS = 25
DEFAULT_RUNS = 3


def make_client(model: str, reasoning: bool) -> LLMClient:
    # Reasoning eats heavily into the output budget; give it more room.
    max_tokens = 16384 if reasoning else 8192
    if model.startswith("claude"):
        return AnthropicClient(
            LLMConfig(
                model=model,
                max_tokens=max_tokens,
                reasoning=reasoning,
                reasoning_tokens=8192 if reasoning else None,
            )
        )
    if model.startswith("deepseek"):
        return DeepSeekClient(
            LLMConfig(
                model=model,
                max_tokens=max_tokens,
                reasoning=reasoning,
                reasoning_effort="high" if reasoning else None,
            )
        )
    return OpenAIClient(
        LLMConfig(
            model=model,
            max_tokens=max_tokens,
            reasoning=reasoning,
            reasoning_effort="medium" if reasoning else None,
        )
    )


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
    parser.add_argument(
        "-n",
        "--runs",
        type=int,
        default=DEFAULT_RUNS,
        help=f"number of runs per (pair, checker) (default: {DEFAULT_RUNS})",
    )
    args = parser.parse_args()

    problem_filter = parse_problem_ids(args.problems)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = Path("runs") / timestamp
    run_dir.mkdir(parents=True, exist_ok=True)

    dataset = Dataset(Path("dataset"))

    # (mode_label, template, include_implicit)
    modes = [
        ("regular", "reformulation.j2", True),
        ("no_definition", "no_definition.j2", True),
        ("allow_implicit", "reformulation.j2", False),
        ("naive", "naive.j2", True),
    ]
    # (label, model, reasoning)
    models = [
        ("gpt-4.1", "gpt-4.1", False),  # gpt-4.1 doesn't support reasoning
        ("opus", "claude-opus-4-6", True),  # claude-opus-4-7 uses adaptive thinking
        ("gpt-5.5", "gpt-5.5", True),
        ("deepseek-pro", "deepseek-v4-pro", True),
        # Omit non-reasoning due to strictly worse performance
        # ("gpt-5.5", "gpt-5.5", False),
        # ("deepseek-pro", "deepseek-v4-pro", False),
        # ("opus", "claude-opus-4-6", False),
        # Omit more affordable models with strictly worse performance
        # ("sonnet", "claude-sonnet-4-6", True),
        # ("sonnet", "claude-sonnet-4-6", False),
        # ("gpt-5.4", "gpt-5.4", True),
        # ("gpt-5.4", "gpt-5.4", False),
        # ("deepseek-flash", "deepseek-v4-flash", True),
        # ("deepseek-flash", "deepseek-v4-flash", False),
    ]

    checkers: list[ReformulationVerifier] = [
        LLMVerifier(
            make_client(model, reasoning),
            name=f"llm_{model_label}{'_reasoning' if reasoning else ''}_{mode_label}",
            template=template,
            include_implicit=include_implicit,
        )
        for model_label, model, reasoning in models
        for mode_label, template, include_implicit in modes
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
    print(
        f"Pairs: {len(pairs)}  Checkers: {len(checkers)}  Runs: {args.runs}  "
        f"Workers: {args.workers}\n"
    )

    tasks = [
        (pair, checker, run_idx)
        for pair in pairs
        for checker in checkers
        for run_idx in range(1, args.runs + 1)
    ]

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
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
