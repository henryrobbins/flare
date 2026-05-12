#!/usr/bin/env python3
"""Combine multiple runs into a new run by symlinking artifact dirs and merging results.

When duplicate (pair_id, method) entries exist across runs, later runs (by run ID
sort order) take precedence.

Usage:
    python scripts/combine_runs.py <run_id1> <run_id2> ...
    python scripts/combine_runs.py --last N          # combine the N most recent runs
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "run_ids", nargs="*", metavar="RUN_ID", default=[], help="Run IDs to combine"
    )
    group.add_argument(
        "--last", type=int, metavar="N", help="Combine the N most recent runs"
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    runs_dir = repo_root / "runs"

    if args.last:
        all_runs = sorted(runs_dir.iterdir(), key=lambda p: p.name)
        selected = [p.name for p in all_runs[-args.last :]]
    else:
        selected = args.run_ids

    if len(selected) < 2:
        print("error: need at least 2 runs to combine", file=sys.stderr)
        sys.exit(1)

    # Validate all runs exist
    for run_id in selected:
        run_path = runs_dir / run_id
        if not run_path.is_dir():
            print(f"error: run not found: {run_path}", file=sys.stderr)
            sys.exit(1)

    new_run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    new_run_dir = runs_dir / new_run_id
    new_pairs_dir = new_run_dir / "pairs"
    new_pairs_dir.mkdir(parents=True)

    print(f"Combining runs: {', '.join(selected)}")
    print(f"New run ID:     {new_run_id}")

    # Process runs in order; later runs overwrite earlier on collision
    merged: dict[tuple[str, str], tuple[str, dict[str, Any]]] = {}

    for run_id in selected:
        run_path = runs_dir / run_id
        results_file = run_path / "results.jsonl"
        if not results_file.exists():
            print(
                f"  warning: {run_id}/results.jsonl not found, skipping",
                file=sys.stderr,
            )
            continue

        with results_file.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                record = json.loads(line)
                key = (record["pair_id"], record["method"])
                merged[key] = (run_id, record)

    # Build the combined run
    symlinked = 0
    skipped = 0

    for (pair_id, method), (source_run_id, record) in merged.items():
        src_artifacts = runs_dir / source_run_id / "pairs" / pair_id / method
        dst_pair_dir = new_pairs_dir / pair_id
        dst_pair_dir.mkdir(exist_ok=True)
        dst_artifacts = dst_pair_dir / method

        if not src_artifacts.exists():
            print(f"  warning: artifacts not found: {src_artifacts}", file=sys.stderr)
            skipped += 1
            continue

        # Make the symlink relative so the run dir is portable
        rel_src = os.path.relpath(src_artifacts, dst_pair_dir)
        dst_artifacts.symlink_to(rel_src)
        symlinked += 1

        # Update artifacts_dir to point to the new run's path
        record["artifacts_dir"] = f"runs/{new_run_id}/pairs/{pair_id}/{method}"

    # Write merged results.jsonl
    results_out = new_run_dir / "results.jsonl"
    with results_out.open("w") as f:
        for _, record in merged.values():
            f.write(json.dumps(record) + "\n")

    print(
        f"Done: {len(merged)} results, {symlinked} symlinks,"
        f" {skipped} missing artifacts"
    )
    print(f"Output: {new_run_dir}")


if __name__ == "__main__":
    main()
