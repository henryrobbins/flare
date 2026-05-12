#!/usr/bin/env python3
"""
Generate per-pair agent action logs as CSV files.

For each pair in a run, produces:
    <run_root>/analysis/agent_time/<pair_id>.csv

Each row is one tool call made at any depth in the agent tree, with columns
for tool name, group, depth, duration, token counts, estimated cost, and
error status.

Run from repo root:
    python scripts/agent_action_log.py -r <run_id>
"""

import argparse
import csv
import json
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

# ── pricing (claude-sonnet-4-6, $/token) ─────────────────────────────────────

PRICE_INPUT = 3.00 / 1_000_000
PRICE_OUTPUT = 15.00 / 1_000_000
PRICE_CACHE_WRITE = 3.75 / 1_000_000
PRICE_CACHE_READ = 0.30 / 1_000_000


def est_cost(input_tok, output_tok, cache_create_tok, cache_read_tok) -> float:
    return (
        input_tok * PRICE_INPUT
        + output_tok * PRICE_OUTPUT
        + cache_create_tok * PRICE_CACHE_WRITE
        + cache_read_tok * PRICE_CACHE_READ
    )


# ── tool grouping ─────────────────────────────────────────────────────────────

TOOL_GROUPS = {
    "lean_lsp": lambda n: n.startswith("mcp__lean-lsp__"),
    "file_io": lambda n: n in ("Read", "Write", "Edit", "Glob", "Grep"),
    "bash": lambda n: n == "Bash",
    "agent": lambda n: n in ("Agent", "Task", "ToolSearch", "Skill"),
    "other": lambda n: True,
}


def group_of(tool_name: str) -> str:
    for g, pred in TOOL_GROUPS.items():
        if pred(tool_name):
            return g
    return "other"


# ── tool input summary ────────────────────────────────────────────────────────


def _rel(path_str: str, cwd: str, repo_root: str = "") -> str:
    """Strip cwd (or repo_root) prefix from an absolute path string."""
    for prefix in filter(None, [cwd, repo_root]):
        if path_str.startswith(prefix + "/"):
            return path_str[len(prefix) + 1 :]
    return path_str


def tool_input_summary(
    tool_name: str, inp: dict, cwd: str, repo_root: str = "", max_len: int = 120
) -> str:
    """Return a short human-readable summary of a tool call's inputs."""

    def trunc(s: str) -> str:
        s = s.replace("\n", " ")
        return s if len(s) <= max_len else s[: max_len - 1] + "…"

    if tool_name in ("Read", "Write", "Edit"):
        return _rel(inp.get("file_path", ""), cwd, repo_root)

    if tool_name == "Bash":
        cmd = inp.get("command", "").strip()
        for prefix in filter(None, [cwd, repo_root]):
            cmd = cmd.replace(prefix + "/", "")
        return trunc(cmd)

    if tool_name == "Glob":
        return inp.get("pattern", "")

    if tool_name == "Grep":
        pat = inp.get("pattern", "")
        path = _rel(inp.get("path", ""), cwd, repo_root)
        return f"{pat}  in  {path}" if path else pat

    if tool_name in ("Agent", "Task"):
        return inp.get("description", "")

    if tool_name == "Skill":
        return inp.get("skill", "")

    if tool_name == "ToolSearch":
        return inp.get("query", "")

    if tool_name.startswith("mcp__lean-lsp__"):
        short = tool_name.split("__")[-1]  # e.g. lean_goal
        # file_path is the most common input; fall back to code snippet
        if "file_path" in inp:
            parts = [_rel(inp["file_path"], cwd)]
            if "line" in inp:
                parts.append(f":{inp['line']}")
                if "column" in inp:
                    parts.append(f":{inp['column']}")
            return "".join(parts)
        if "code" in inp:
            return trunc(inp["code"])
        if "snippets" in inp:
            snips = inp["snippets"]
            return trunc(f"[{len(snips)} snippets] " + snips[0] if snips else "")
        return ""

    # generic fallback: dump first string value found
    for v in inp.values():
        if isinstance(v, str):
            return trunc(v)
    return ""


# ── core parser ───────────────────────────────────────────────────────────────

CSV_FIELDS = [
    "action_index",
    "depth",  # 0 = root, 1 = inside a subagent task
    "tool_name",
    "tool_group",
    "tool_input",  # concise summary of what was passed to the tool
    "task_context",  # description of the containing subagent (empty at depth 0)
    "subtask_description",  # for Task/Agent calls: description of the launched task
    "subtask_tool_uses",  # for Task/Agent calls: tool use count from task_notification
    "start_ms",  # ms since first tool result (wall-clock relative to session start)
    "end_ms",  # ms since first tool result (wall-clock relative to session start)
    "duration_ms",  # end_ms - start_ms
    "input_tokens",
    "cache_create_tokens",
    "cache_read_tokens",
    "output_tokens",
    "cost_usd_est",
    "is_error",
]

_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def _parse_ts(s: str) -> datetime:
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def _build_tool_timestamps(events: list[dict]) -> dict[str, datetime]:
    """Map each tool_use_id to the timestamp of its user-event result."""
    ts_map: dict[str, datetime] = {}
    for e in events:
        if e.get("type") == "user" and e.get("timestamp"):
            ts = _parse_ts(e["timestamp"])
            for c in e.get("message", {}).get("content", []):
                if c.get("type") == "tool_result":
                    ts_map[c["tool_use_id"]] = ts
    return ts_map


def _build_task_durations(events: list[dict]) -> dict[str, list[int]]:
    """
    Return {task_id: [delta_ms_for_tool_1, delta_ms_for_tool_2, ...]}.
    Fallback for runs that have task_progress events (older format).
    """
    by_task: dict[str, list] = defaultdict(list)
    for e in events:
        if e.get("type") == "system" and e.get("subtype") == "task_progress":
            by_task[e["task_id"]].append(e)

    result: dict[str, list[int]] = {}
    for tid, evs in by_task.items():
        evs.sort(key=lambda e: e["usage"]["tool_uses"])
        deltas: list[int] = []
        prev = 0
        for ev in evs:
            cur = ev["usage"]["duration_ms"]
            deltas.append(max(cur - prev, 0))
            prev = cur
        result[tid] = deltas
    return result


def parse_action_log(path: Path) -> list[dict]:
    try:
        events = [json.loads(l) for l in path.read_text().splitlines() if l.strip()]
    except Exception as e:
        print(f"  WARN: could not read {path}: {e}", file=sys.stderr)
        return []

    init = next((e for e in events if e.get("subtype") == "init"), {})
    cwd = init.get("cwd", "").rstrip("/")
    repo_root = str(Path(__file__).parent.parent).rstrip("/")

    # ── task metadata ──────────────────────────────────────────────────────
    # task_id -> {description, tool_use_id, final_usage, task_type}
    task_meta: dict[str, dict] = {}
    for e in events:
        sub = e.get("subtype")
        if sub == "task_started":
            task_meta[e["task_id"]] = {
                "description": e.get("description", ""),
                "tool_use_id": e.get("tool_use_id"),
                "task_type": e.get("task_type", ""),
                "final_usage": {},
                "status": None,
            }
        elif sub == "task_notification":
            if e["task_id"] in task_meta:
                task_meta[e["task_id"]]["final_usage"] = e.get("usage", {})
                task_meta[e["task_id"]]["status"] = e.get("status")

    # reverse map: tool_use_id -> task_id  (for Task calls at root or subagent level)
    tool_use_to_task: dict[str, str] = {
        m["tool_use_id"]: tid for tid, m in task_meta.items() if m["tool_use_id"]
    }

    # ── timestamp map: tool_use_id -> completion datetime ─────────────────
    # User events carry ISO timestamps when the tool result was returned.
    # Duration for call i = completion_ts[i] - completion_ts[i-1].
    # This captures both tool execution time and API round-trip wait time.
    tool_completion_ts = _build_tool_timestamps(events)

    # Fallback: task_progress-based durations for older run formats.
    task_durations = _build_task_durations(events)
    task_call_count: dict[str, int] = defaultdict(int)

    # ── resolve parent chain -> task_id for subagent events ───────────────
    def depth_and_task(parent_tuid: str | None) -> tuple[int, str | None]:
        if parent_tuid is None:
            return 0, None
        if parent_tuid in tool_use_to_task:
            return 1, tool_use_to_task[parent_tuid]
        return 1, None

    # ── tool results (error flag) ──────────────────────────────────────────
    tool_result_error: dict[str, bool] = {}
    for e in events:
        if e.get("type") == "user":
            for c in e.get("message", {}).get("content", []):
                if c.get("type") == "tool_result":
                    tool_result_error[c["tool_use_id"]] = bool(c.get("is_error", False))

    # ── collect ordered tool-use records ──────────────────────────────────
    # We need two passes: first collect all rows, then fill in start/end_ms.
    rows: list[dict] = []
    action_idx = 0

    for e in events:
        if e.get("type") != "assistant":
            continue

        msg = e.get("message", {})
        usage = msg.get("usage", {})
        parent = e.get("parent_tool_use_id")
        content = msg.get("content", [])

        tool_uses = [c for c in content if c.get("type") == "tool_use"]
        if not tool_uses:
            continue

        depth, task_id = depth_and_task(parent)
        task_desc = task_meta.get(task_id, {}).get("description", "") if task_id else ""

        inp_tok = usage.get("input_tokens", 0)
        cc_tok = usage.get("cache_creation_input_tokens", 0)
        cr_tok = usage.get("cache_read_input_tokens", 0)
        out_tok = usage.get("output_tokens", 0)

        for tu in tool_uses:
            tool_name = tu["name"]
            tuid = tu["id"]
            ti_summary = tool_input_summary(
                tool_name, tu.get("input", {}), cwd, repo_root
            )

            # subtask info (if this call launches a subagent)
            subtask_desc = ""
            subtask_tool_uses = ""
            if tuid in tool_use_to_task:
                child_tid = tool_use_to_task[tuid]
                subtask_desc = task_meta.get(child_tid, {}).get("description", "")
                fu = task_meta.get(child_tid, {}).get("final_usage", {})
                subtask_tool_uses = fu.get("tool_uses", "")

            rows.append(
                {
                    "action_index": action_idx,
                    "depth": depth,
                    "tool_name": tool_name,
                    "tool_group": group_of(tool_name),
                    "tool_input": ti_summary,
                    "task_context": task_desc,
                    "subtask_description": subtask_desc,
                    "subtask_tool_uses": subtask_tool_uses,
                    "_tuid": tuid,  # temporary; stripped before CSV write
                    "_task_id": task_id,  # temporary
                    "start_ms": "",
                    "end_ms": "",
                    "duration_ms": "",
                    "input_tokens": inp_tok,
                    "cache_create_tokens": cc_tok,
                    "cache_read_tokens": cr_tok,
                    "output_tokens": out_tok,
                    "cost_usd_est": round(
                        est_cost(inp_tok, out_tok, cc_tok, cr_tok), 6
                    ),
                    "is_error": tool_result_error.get(tuid, False),
                }
            )
            action_idx += 1

    # ── fill in timing ─────────────────────────────────────────────────────
    # Primary: use completion timestamps from user events.
    # t0 = first completion timestamp; all times are relative to it.
    # Duration[i] = ts[i] - ts[i-1]; start[i] = end[i-1]; start[0] = 0.
    tuids = [r["_tuid"] for r in rows]
    ts_list = [tool_completion_ts.get(uid) for uid in tuids]

    if any(t is not None for t in ts_list):
        t0 = next(t for t in ts_list if t is not None)
        prev_end_ms = 0
        for i, row in enumerate(rows):
            ts = ts_list[i]
            if ts is not None:
                end_ms = round((ts - t0).total_seconds() * 1000)
                row["start_ms"] = prev_end_ms
                row["end_ms"] = end_ms
                row["duration_ms"] = max(end_ms - prev_end_ms, 0)
                prev_end_ms = end_ms
            else:
                # No timestamp: fall back to task_progress delta if available.
                task_id = row["_task_id"]
                if task_id and task_id in task_durations:
                    idx = task_call_count[task_id]
                    deltas = task_durations[task_id]
                    if idx < len(deltas):
                        dur = deltas[idx]
                        row["start_ms"] = prev_end_ms
                        row["end_ms"] = prev_end_ms + dur
                        row["duration_ms"] = dur
                        prev_end_ms += dur
                    task_call_count[task_id] += 1
    else:
        # No timestamps at all: fall back entirely to task_progress deltas.
        for row in rows:
            task_id = row["_task_id"]
            if task_id and task_id in task_durations:
                idx = task_call_count[task_id]
                deltas = task_durations[task_id]
                if idx < len(deltas):
                    row["duration_ms"] = deltas[idx]
                task_call_count[task_id] += 1

    # strip temporaries
    for row in rows:
        row.pop("_tuid", None)
        row.pop("_task_id", None)

    return rows


# ── main ──────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(
        description="Generate per-pair agent action log CSVs."
    )
    parser.add_argument(
        "-r", "--run-id", required=True, help="Run ID (e.g. 20260425T200341Z)"
    )
    args = parser.parse_args()

    run_root = Path("runs") / args.run_id
    files = sorted(run_root.glob("pairs/*/flare*/wd/agent_output.jsonl"))

    if not files:
        print(f"No agent_output.jsonl files found under {run_root}")
        sys.exit(1)

    out_dir = run_root / "analysis" / "agent_time"
    out_dir.mkdir(parents=True, exist_ok=True)

    SUM_COLS = [
        "input_tokens",
        "cache_create_tokens",
        "cache_read_tokens",
        "output_tokens",
        "cost_usd_est",
    ]
    GROUP_COLS = ["tool_name", "tool_group", "tool_input"]

    agg: dict[tuple, dict] = defaultdict(lambda: {c: 0.0 for c in SUM_COLS})

    for f in files:
        pair_id = f.parts[-4]
        rows = parse_action_log(f)

        out_path = out_dir / f"{pair_id}.csv"
        with out_path.open("w", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
            writer.writeheader()
            writer.writerows(rows)

        for row in rows:
            key = tuple(row[c] for c in GROUP_COLS)
            for col in SUM_COLS:
                agg[key][col] += float(row[col] or 0)

        print(
            f"  {pair_id:<25} {len(rows):>4} actions → {out_path.relative_to(run_root)}"
        )

    # write summary
    summary_path = out_dir / "summary.csv"
    summary_fields = GROUP_COLS + SUM_COLS
    with summary_path.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=summary_fields)
        writer.writeheader()
        for key, totals in sorted(agg.items(), key=lambda x: -x[1]["cost_usd_est"]):
            row = dict(zip(GROUP_COLS, key)) | {
                c: round(totals[c], 6) if c == "cost_usd_est" else int(totals[c])
                for c in SUM_COLS
            }
            writer.writerow(row)

    print(f"\nWrote {len(files)} CSV(s) + summary.csv to {out_dir}")


if __name__ == "__main__":
    main()
