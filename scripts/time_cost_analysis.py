#!/usr/bin/env python3
"""
Analyse where time is spent by the flare method.

Per-tool wall time is estimated from task_progress delta approach:
  - Each task_progress event has a cumulative duration_ms within its task_id.
  - The delta between consecutive events within a task ≈ time spent on the
    tool named in last_tool_name of the *later* event.

Run from repo root:
    python scripts/time_analysis.py [runs/.../results.jsonl]
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

# ── config ────────────────────────────────────────────────────────────────────

TOOL_GROUPS = {
    "lean_lsp": lambda n: n.startswith("mcp__lean-lsp__"),
    "file_io": lambda n: n in ("Read", "Write", "Edit", "Glob", "Grep"),
    "bash": lambda n: n == "Bash",
    "agent": lambda n: n in ("Agent", "Task", "ToolSearch", "Skill"),
    "other": lambda n: True,  # catch-all
}


def group_of(tool_name: str) -> str:
    for g, pred in TOOL_GROUPS.items():
        if pred(tool_name):
            return g
    return "other"


# ── helpers ───────────────────────────────────────────────────────────────────


def per_tool_time_ms(events: list[dict]) -> dict[str, int]:
    """Return {tool_name: total_ms} using task_progress deltas."""
    # group progress events by task_id, sorted by tool_uses counter
    by_task: dict[str, list] = defaultdict(list)
    for e in events:
        if e["type"] == "system" and e.get("subtype") == "task_progress":
            by_task[e["task_id"]].append(e)

    totals: dict[str, int] = defaultdict(int)
    for task_events in by_task.values():
        task_events.sort(key=lambda e: e["usage"]["tool_uses"])
        prev_ms = 0
        for ev in task_events:
            cur_ms = ev["usage"]["duration_ms"]
            delta = cur_ms - prev_ms
            tool = ev.get("last_tool_name") or "unknown"
            totals[tool] += max(delta, 0)
            prev_ms = cur_ms
    return dict(totals)


def load_pair(path: Path) -> dict | None:
    """Parse one claude_output.jsonl; return summary dict or None."""
    try:
        events = [json.loads(l) for l in path.read_text().splitlines() if l.strip()]
    except Exception as e:
        print(f"  WARN: could not read {path}: {e}", file=sys.stderr)
        return None

    result = next((e for e in events if e["type"] == "result"), None)

    tool_calls: dict[str, int] = defaultdict(int)
    for e in events:
        if e["type"] == "assistant":
            for c in e.get("message", {}).get("content", []):
                if c.get("type") == "tool_use":
                    tool_calls[c["name"]] += 1

    return {
        "pair_id": path.parts[-3],
        "finished": result is not None,
        "duration_ms": result.get("duration_ms", 0) if result else 0,
        "duration_api_ms": result.get("duration_api_ms", 0) if result else 0,
        "cost_usd": result.get("total_cost_usd", 0.0) if result else 0.0,
        "num_turns": result.get("num_turns", 0) if result else 0,
        "is_error": result.get("is_error", False) if result else False,
        "usage": result.get("usage", {}) if result else {},
        "tool_calls": dict(tool_calls),
        "tool_time_ms": per_tool_time_ms(events),
    }


def fmt_ms(ms: float) -> str:
    if ms >= 60_000:
        return f"{ms/60_000:.1f}m"
    return f"{ms/1_000:.1f}s"


def fmt_pct(num, denom) -> str:
    if denom == 0:
        return "  -  "
    return f"{100*num/denom:5.1f}%"


# ── main ──────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Analyse time/cost for flare runs.")
    parser.add_argument(
        "-r", "--run-id", required=True, help="Run ID (e.g. 20260425T200341Z)"
    )
    args = parser.parse_args()

    run_root = Path("runs") / args.run_id
    files = sorted(run_root.glob("pairs/*/flare/claude_output.jsonl"))

    if not files:
        print(f"No claude_output.jsonl files found under {run_root}")
        sys.exit(1)

    pairs = [p for p in (load_pair(f) for f in files) if p is not None]
    finished = sum(1 for p in pairs if p["finished"])
    print(
        f"Loaded {len(pairs)} pair(s) ({finished} finished, {len(pairs) - finished} in-progress)\n"
    )

    # ── 1. Per-pair summary ────────────────────────────────────────────────
    print("=" * 80)
    print("PER-PAIR SUMMARY")
    print("=" * 80)
    hdr = f"{'Pair':<22} {'Status':>8} {'Wall':>6} {'API':>6} {'Wait':>6} {'Cost':>7} {'Turns':>5} {'Tools':>5}"
    print(hdr)
    print("-" * len(hdr))
    for p in pairs:
        wall = p["duration_ms"]
        api = p["duration_api_ms"]
        wait = wall - api
        total_tools = sum(p["tool_calls"].values())
        status = "done" if p["finished"] else "running"
        print(
            f"{p['pair_id']:<22} {status:>8} {fmt_ms(wall):>6} {fmt_ms(api):>6} "
            f"{fmt_ms(wait):>6} ${p['cost_usd']:>6.2f} {p['num_turns']:>5} {total_tools:>5}"
        )

    # ── 2. Aggregate tool-call counts ─────────────────────────────────────
    print()
    print("=" * 80)
    print("TOOL CALL COUNTS (aggregated across all pairs)")
    print("=" * 80)
    total_calls: dict[str, int] = defaultdict(int)
    for p in pairs:
        for t, n in p["tool_calls"].items():
            total_calls[t] += n

    by_group: dict[str, dict[str, int]] = defaultdict(dict)
    for t, n in total_calls.items():
        by_group[group_of(t)][t] = n

    grand_calls = sum(total_calls.values())
    for g in TOOL_GROUPS:
        if g not in by_group:
            continue
        g_total = sum(by_group[g].values())
        print(
            f"\n  [{g.upper()}]  {g_total} calls  ({fmt_pct(g_total, grand_calls)} of total)"
        )
        for t, n in sorted(by_group[g].items(), key=lambda x: -x[1]):
            print(f"    {t:<45} {n:>5}  ({fmt_pct(n, grand_calls)})")
    print(f"\n  GRAND TOTAL: {grand_calls} tool calls")

    # ── 3. Aggregate tool-time breakdown ──────────────────────────────────
    print()
    print("=" * 80)
    print("ESTIMATED TOOL WALL TIME (from task_progress deltas)")
    print("=" * 80)
    total_time: dict[str, int] = defaultdict(int)
    for p in pairs:
        for t, ms in p["tool_time_ms"].items():
            total_time[t] += ms

    grand_time = sum(total_time.values())
    by_group_time: dict[str, dict[str, int]] = defaultdict(dict)
    for t, ms in total_time.items():
        by_group_time[group_of(t)][t] = ms

    for g in TOOL_GROUPS:
        if g not in by_group_time:
            continue
        g_total = sum(by_group_time[g].values())
        print(
            f"\n  [{g.upper()}]  {fmt_ms(g_total)}  ({fmt_pct(g_total, grand_time)} of tracked time)"
        )
        for t, ms in sorted(by_group_time[g].items(), key=lambda x: -x[1]):
            print(f"    {t:<45} {fmt_ms(ms):>7}  ({fmt_pct(ms, grand_time)})")
    print(f"\n  TOTAL TRACKED TOOL TIME: {fmt_ms(grand_time)}")

    # compare with sum of wall times
    total_wall = sum(p["duration_ms"] for p in pairs)
    total_api = sum(p["duration_api_ms"] for p in pairs)
    print(f"  Sum of wall times:       {fmt_ms(total_wall)}")
    print(f"  Sum of API times:        {fmt_ms(total_api)}")
    print(f"  Unaccounted (wall-tracked): {fmt_ms(total_wall - grand_time)}")

    # ── 4. Avg time per call ───────────────────────────────────────────────
    print()
    print("=" * 80)
    print("AVERAGE TIME PER CALL (top tools by total time)")
    print("=" * 80)
    rows = []
    for t in total_time:
        calls = total_calls.get(t, 0)
        ms = total_time[t]
        avg = ms / calls if calls else 0
        rows.append((t, ms, calls, avg))
    rows.sort(key=lambda x: -x[1])

    print(f"  {'Tool':<45} {'Total':>7} {'Calls':>6} {'Avg/call':>9}")
    print("  " + "-" * 72)
    for t, ms, calls, avg in rows[:20]:
        print(f"  {t:<45} {fmt_ms(ms):>7} {calls:>6} {fmt_ms(avg):>9}")

    # ── 5. Cost summary ───────────────────────────────────────────────────
    print()
    print("=" * 80)
    print("COST SUMMARY")
    print("=" * 80)
    total_cost = sum(p["cost_usd"] for p in pairs)
    print(f"  Total cost:    ${total_cost:.4f}")
    print(f"  Pairs:         {len(pairs)}")
    print(f"  Avg per pair:  ${total_cost/len(pairs):.4f}")
    print()

    # token breakdown
    agg_tokens: dict[str, int] = defaultdict(int)
    for p in pairs:
        u = p["usage"]
        agg_tokens["input"] += u.get("input_tokens", 0)
        agg_tokens["output"] += u.get("output_tokens", 0)
        agg_tokens["cache_create"] += u.get("cache_creation_input_tokens", 0)
        agg_tokens["cache_read"] += u.get("cache_read_input_tokens", 0)
    for k, v in agg_tokens.items():
        print(f"  {k:<20} {v:>12,} tokens")


if __name__ == "__main__":
    main()
