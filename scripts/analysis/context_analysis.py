#!/usr/bin/env python3
"""Per-file context-read summary across artifact dirs in a run.

For each artifact dir, aggregates Read/Bash/Edit/lean-lsp tool calls by
target_path and reports read counts, total chars, estimated tokens.

Token estimate is ~4 chars / token (Claude rule of thumb).

Usage:
    python scripts/analysis/context_analysis.py -r 20260512T050406Z
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.analysis.agent_jsonl import discover_artifacts, read_log_csv, write_log_csv


def _int(s: Any) -> int:
    try:
        return int(s)
    except (TypeError, ValueError):
        return 0


def _tokens(chars: int) -> int:
    return chars // 4


def per_artifact(
    rows: list[dict[str, Any]],
) -> tuple[dict[str, list[int]], int]:
    """{target_path: [chars, ...]} for read-like tool calls, plus a total."""
    by_path: dict[str, list[int]] = defaultdict(list)
    total_chars = 0
    for r in rows:
        if r["event_type"] != "tool_call":
            continue
        path = r.get("target_path") or ""
        chars = _int(r.get("output_chars"))
        if not path:
            continue
        # Skip writes/edits — those don't add to context the agent reads.
        if r.get("tool_name") in ("write", "edit", "file_change"):
            continue
        by_path[path].append(chars)
        total_chars += chars
    return by_path, total_chars


def print_artifact(
    label: str, by_path: dict[str, list[int]], total_chars: int, top: int
) -> None:
    print(f"\n## {label}")
    print(f"   total: {total_chars:,} chars  (~{_tokens(total_chars):,} tokens)")
    rows = sorted(
        ((p, sum(cs), len(cs)) for p, cs in by_path.items()),
        key=lambda x: -x[1],
    )
    if top:
        rows = rows[:top]
    print(f"   {'file':<58}{'reads':>6}  {'chars':>10}  {'~tokens':>9}")
    for path, ch, n in rows:
        print(f"   {path[:58]:<58}{n:>6}  {ch:>10,}  {_tokens(ch):>9,}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("-r", "--run-id", required=True)
    p.add_argument(
        "-i",
        "--individual",
        action="store_true",
        help="Show per-artifact breakdown instead of the aggregate summary",
    )
    p.add_argument("--top", type=int, default=15, help="Top-N files")
    args = p.parse_args()

    run_dir = Path("runs") / args.run_id
    artifacts = discover_artifacts(run_dir)
    if not artifacts:
        sys.exit(f"No artifact dirs found under {run_dir}")

    if args.individual:
        grand_chars = 0
        for d in artifacts:
            rows = read_log_csv(write_log_csv(d))
            by_path, total = per_artifact(rows)
            print_artifact(f"{d.parent.name}/{d.name}", by_path, total, args.top)
            grand_chars += total
        print(
            f"\nAggregate across {len(artifacts)} artifact(s): "
            f"{grand_chars:,} chars (~{_tokens(grand_chars):,} tokens)"
        )
        return

    # Aggregate: sum chars/read counts across every artifact dir.
    agg_paths: dict[str, list[int]] = defaultdict(list)
    for d in artifacts:
        rows = read_log_csv(write_log_csv(d))
        by_path, _ = per_artifact(rows)
        for path, chars_list in by_path.items():
            agg_paths[path].extend(chars_list)
    total = sum(sum(cs) for cs in agg_paths.values())
    print_artifact(
        f"aggregate over {len(artifacts)} artifact(s)", agg_paths, total, args.top
    )


if __name__ == "__main__":
    main()
