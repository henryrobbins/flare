#!/usr/bin/env python3
"""Time and cost summary across artifact dirs in a run.

Default: a single aggregate summary (totals + per-tool_group breakdown).
With `-i`: per-artifact rows. When the agent didn't report cost_usd
(codex), it's estimated from input/output tokens using the project pricing
table (src.llm_client.compute_cost_usd) and config.json's model.

Usage:
    python scripts/analysis/time_cost_analysis.py -r 20260512T050406Z
    python scripts/analysis/time_cost_analysis.py -r 20260512T050406Z -i
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.analysis.agent_jsonl import discover_artifacts, read_log_csv, write_log_csv
from src.llm_client import compute_cost_usd


def _int(s) -> int:
    try:
        return int(s)
    except (TypeError, ValueError):
        return 0


def _float(s) -> float:
    try:
        return float(s)
    except (TypeError, ValueError):
        return 0.0


def _fmt_dur(ms: float) -> str:
    if ms >= 60_000:
        return f"{ms/60_000:5.1f}m"
    if ms >= 1_000:
        return f"{ms/1_000:5.1f}s"
    return f"{ms:>5.0f}ms"


def _model(artifact_dir: Path) -> str:
    cfg_path = artifact_dir / "config.json"
    if not cfg_path.exists():
        return ""
    return json.loads(cfg_path.read_text()).get("model", "")


def summarize(rows: list[dict], fallback_model: str) -> dict:
    """Aggregate one artifact's rows. cost_usd falls back to a token-priced
    estimate when the agent didn't report cost on any model_turn."""
    turns = 0
    tools = 0
    tokens = defaultdict(int)
    reported_cost = 0.0
    any_cost_reported = False
    wall_ms = 0
    for r in rows:
        if r["event_type"] == "model_turn":
            turns += 1
            for col in (
                "input_tokens",
                "output_tokens",
                "cache_create_tokens",
                "cache_read_tokens",
                "reasoning_tokens",
            ):
                tokens[col] += _int(r.get(col))
            c = r.get("cost_usd")
            if c not in ("", None):
                reported_cost += _float(c)
                any_cost_reported = True
        elif r["event_type"] == "tool_call":
            tools += 1
        end = _int(r.get("end_ms"))
        if end > wall_ms:
            wall_ms = end

    if any_cost_reported:
        cost = reported_cost
        cost_estimated = False
    else:
        est = compute_cost_usd(
            fallback_model,
            tokens["input_tokens"] + tokens["cache_read_tokens"],
            tokens["output_tokens"] + tokens.get("reasoning_tokens", 0),
        )
        cost = est or 0.0
        cost_estimated = est is not None

    return {
        "turns": turns,
        "tools": tools,
        "tokens": dict(tokens),
        "cost_usd": cost,
        "cost_estimated": cost_estimated,
        "wall_ms": wall_ms,
        "model": fallback_model,
    }


def _print_summary(label: str, s: dict) -> None:
    tk = s["tokens"]
    print(f"## {label}")
    if s["model"]:
        print(f"   model:  {s['model']}")
    print(f"   turns:  {s['turns']}    tools: {s['tools']}    wall: {_fmt_dur(s['wall_ms'])}")
    print(
        f"   tokens: in={tk.get('input_tokens', 0):,}  out={tk.get('output_tokens', 0):,}  "
        f"cache_write={tk.get('cache_create_tokens', 0):,}  "
        f"cache_read={tk.get('cache_read_tokens', 0):,}"
        + (f"  reasoning={tk['reasoning_tokens']:,}" if tk.get("reasoning_tokens") else "")
    )
    cost_str = f"${s['cost_usd']:.4f}" if s["cost_usd"] else "$0.0000"
    suffix = " (estimated)" if s["cost_estimated"] else ""
    print(f"   cost:   {cost_str}{suffix}")


def _print_group_table(group_calls: dict, group_ms: dict) -> None:
    print()
    print(f"  {'tool_group':<12} {'calls':>6}   {'time':>8}")
    for g in sorted(group_calls, key=lambda k: -group_ms[k]):
        print(f"  {g:<12} {group_calls[g]:>6}   {_fmt_dur(group_ms[g]):>8}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("-r", "--run-id", required=True)
    p.add_argument(
        "-i",
        "--individual",
        action="store_true",
        help="Show per-artifact breakdown instead of the aggregate summary",
    )
    args = p.parse_args()

    run_dir = Path("runs") / args.run_id
    artifacts = discover_artifacts(run_dir)
    if not artifacts:
        sys.exit(f"No artifact dirs found under {run_dir}")

    group_calls: dict[str, int] = defaultdict(int)
    group_ms: dict[str, int] = defaultdict(int)

    if args.individual:
        cols = [
            "pair / artifact",
            "model",
            "turns",
            "tools",
            "wall",
            "in",
            "out",
            "cache+",
            "cache-",
            "cost",
        ]
        widths = [42, 22, 5, 5, 7, 9, 9, 9, 11, 12]
        fmt = "  ".join("{:<" + str(w) + "}" for w in widths)
        print(fmt.format(*cols))
        print("-" * (sum(widths) + 2 * (len(widths) - 1)))
        for d in artifacts:
            rows = read_log_csv(write_log_csv(d))
            s = summarize(rows, _model(d))
            tk = s["tokens"]
            cost_str = f"${s['cost_usd']:.4f}" if s["cost_usd"] else "    -"
            if s["cost_estimated"] and s["cost_usd"]:
                cost_str += "*"
            label = f"{d.parent.name}/{d.name}"
            print(
                fmt.format(
                    label[:42],
                    (s["model"] or "")[:22],
                    s["turns"],
                    s["tools"],
                    _fmt_dur(s["wall_ms"]),
                    f"{tk.get('input_tokens', 0):,}",
                    f"{tk.get('output_tokens', 0):,}",
                    f"{tk.get('cache_create_tokens', 0):,}",
                    f"{tk.get('cache_read_tokens', 0):,}",
                    cost_str,
                )
            )
            for r in rows:
                if r["event_type"] != "tool_call":
                    continue
                g = r.get("tool_group") or "other"
                group_calls[g] += 1
                group_ms[g] += _int(r.get("duration_ms"))
        print("\n  * = cost estimated from tokens (agent did not report)")
        _print_group_table(group_calls, group_ms)
        return

    # Aggregate path: combine all artifacts into one summary.
    agg_tokens: dict[str, int] = defaultdict(int)
    agg_turns = 0
    agg_tools = 0
    agg_cost = 0.0
    any_estimated = False
    max_wall = 0
    for d in artifacts:
        rows = read_log_csv(write_log_csv(d))
        s = summarize(rows, _model(d))
        agg_turns += s["turns"]
        agg_tools += s["tools"]
        agg_cost += s["cost_usd"]
        if s["cost_estimated"]:
            any_estimated = True
        max_wall = max(max_wall, s["wall_ms"])
        for k, v in s["tokens"].items():
            agg_tokens[k] += v
        for r in rows:
            if r["event_type"] != "tool_call":
                continue
            g = r.get("tool_group") or "other"
            group_calls[g] += 1
            group_ms[g] += _int(r.get("duration_ms"))

    _print_summary(
        f"aggregate over {len(artifacts)} artifact(s)",
        {
            "turns": agg_turns,
            "tools": agg_tools,
            "tokens": dict(agg_tokens),
            "cost_usd": agg_cost,
            "cost_estimated": any_estimated,
            "wall_ms": max_wall,
            "model": "",
        },
    )
    _print_group_table(group_calls, group_ms)


if __name__ == "__main__":
    main()
