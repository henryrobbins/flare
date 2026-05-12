#!/usr/bin/env python3
"""Summarize context read (Read tool, Bash file reads, skill loads) in agent_output.jsonl traces.

Usage:
  Single file:  read_context_summary.py path/to/agent_output.jsonl
  Run summary:  read_context_summary.py -r runs/20260426T154132Z
"""

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parent.parent

_READ_CMDS = re.compile(
    r"""
    (?:^|[|;&]\s*)
    (?:sudo\s+)?
    (?:cat|head|tail|less|more|bat|pygmentize)
    (?:\s+(?:-[^\s]+))*
    (?P<files>(?:\s+(?!-)[^\s|;&<>]+)+)
    """,
    re.VERBOSE | re.MULTILINE,
)

# Matches absolute paths in a shell command (excluding /dev/null)
_ABS_PATH = re.compile(
    r"(?<!['\"\w])/(?!dev/null\b)(?:[A-Za-z0-9_.~-]+/)+[A-Za-z0-9_.~-]*"
)

_SHELL_CMDS = frozenset(
    "echo ls find grep awk sed rm cp mv mkdir touch chmod chown python python3 "
    "bash sh cd pwd which type true false exit sort uniq wc xargs tee tr cut printf".split()
)


def _extract_files_from_bash(command: str) -> list[str]:
    paths = []
    for m in _READ_CMDS.finditer(command):
        for token in m.group("files").split():
            if token.startswith("-"):
                continue
            # skip redirection tokens and bare integers (e.g. "2" from "2>/dev/null")
            if token in (">", ">>", "2>&1", "/dev/null") or token.isdigit():
                continue
            # skip shell variables ($f, "$f", etc.)
            if "$" in token:
                continue
            # skip quoted non-path strings ('===', "msg", etc.)
            if token[0] in ("'", '"'):
                continue
            # skip bare command names picked up as spurious file arguments
            if token in _SHELL_CMDS:
                continue
            paths.append(token)
    return paths


def estimate_tokens(chars: int) -> int:
    return max(1, chars // 4)


def _content_str(raw) -> str:
    if isinstance(raw, list):
        return "".join(
            c.get("text", "") if isinstance(c, dict) else str(c) for c in raw
        )
    return str(raw) if raw is not None else ""


def _strip_wd(path_str: str, wd: Path) -> tuple[str, bool]:
    """Return (display_path, is_outside_wd).

    Strips the wd prefix. Relative paths (including ../ escapes) are resolved
    against wd before checking. Returns is_outside_wd=True for paths that fall
    outside the working directory.
    """
    if path_str.startswith("/"):
        p = Path(path_str)
    else:
        # resolve relative path against wd — handles ../.. escapes correctly
        p = (wd / path_str).resolve()
    try:
        rel = p.relative_to(wd)
        return str(rel), False
    except ValueError:
        return str(p), True


def parse_trace(jsonl_path: Path) -> tuple[list[dict], list[dict], list[dict], dict]:
    """Return (file_entries, outside_entries, attempted_outside_entries, result_summary).

    file_entries: [{file_path, read_count, total_chars, total_tokens}] — paths inside wd
    outside_entries: same shape but for paths outside the wd (successful reads)
    attempted_outside_entries: [{file_path, attempt_count}] — denied tool calls that targeted outside-wd paths
    """
    # The agent runs inside the Docker container where wd is bind-mounted at
    # /workspace/wd, so all absolute paths in the trace are rooted there.
    wd = Path("/workspace/wd")

    tool_calls: dict[str, dict] = {}
    tool_results: dict[str, str] = {}
    denied_tids: set[str] = set()
    result_summary: dict = {}
    # display_path -> list of char counts
    inside: dict[str, list[int]] = defaultdict(list)
    outside: dict[str, list[int]] = defaultdict(list)
    attempted_outside: dict[str, int] = defaultdict(int)

    with jsonl_path.open() as f:
        for line in f:
            obj = json.loads(line)
            t = obj.get("type")

            if t == "assistant":
                for item in obj.get("message", {}).get("content", []):
                    if item.get("type") == "tool_use":
                        tool_calls[item["id"]] = {
                            "name": item.get("name", ""),
                            "input": item.get("input", {}),
                        }

            elif t == "user":
                for item in obj.get("message", {}).get("content", []):
                    if item.get("type") == "tool_result":
                        tid = item.get("tool_use_id", "")
                        content_str = _content_str(item.get("content"))
                        if tid in tool_calls:
                            tool_results[tid] = content_str
                        if "has been denied" in content_str:
                            denied_tids.add(tid)
                    elif item.get("type") == "text":
                        text = item.get("text", "")
                        if text.startswith("Base directory for this skill:"):
                            first_line, _, _ = text.partition("\n")
                            skill_dir = first_line.removeprefix(
                                "Base directory for this skill:"
                            ).strip()
                            skill_md_path = skill_dir.rstrip("/") + "/SKILL.md"
                            disp, is_out = _strip_wd(skill_md_path, wd)
                            (outside if is_out else inside)[disp].append(len(text))

            elif t == "result":
                result_summary = obj

    for tid, call in tool_calls.items():
        name = call["name"]
        inp = call["input"]
        content = tool_results.get(tid, "")

        if tid in denied_tids:
            # Record attempted outside-wd paths for denied calls
            if name == "Read":
                fpath = inp.get("file_path", "")
                disp, is_out = _strip_wd(fpath, wd)
                if is_out:
                    attempted_outside[disp] += 1
            elif name == "Bash":
                command = inp.get("command", "")
                for m in _ABS_PATH.finditer(command):
                    disp, is_out = _strip_wd(m.group(0), wd)
                    if is_out:
                        attempted_outside[disp] += 1
            continue

        if name == "Read":
            fpath = inp.get("file_path", "")
            disp, is_out = _strip_wd(fpath, wd)
            (outside if is_out else inside)[disp].append(len(content))

        elif name == "Bash":
            command = inp.get("command", "")
            files = _extract_files_from_bash(command)
            if not files:
                continue
            chars_each = len(content) // len(files)
            for fpath in files:
                disp, is_out = _strip_wd(fpath, wd)
                (outside if is_out else inside)[disp].append(chars_each)

    def _to_entries(accum: dict[str, list[int]]) -> list[dict]:
        rows = [
            {
                "file_path": fp,
                "read_count": len(cs),
                "total_chars": sum(cs),
                "total_tokens": sum(estimate_tokens(c) for c in cs),
            }
            for fp, cs in accum.items()
        ]
        rows.sort(key=lambda r: r["total_tokens"], reverse=True)
        return rows

    attempted_entries = sorted(
        [{"file_path": fp, "attempt_count": n} for fp, n in attempted_outside.items()],
        key=lambda r: r["attempt_count"],
        reverse=True,
    )
    return _to_entries(inside), _to_entries(outside), attempted_entries, result_summary


def aggregate_run(
    run_dir: Path,
) -> tuple[list[dict], list[dict], list[dict], list[dict], int]:
    """Aggregate file read stats across all pairs in a run.

    Returns (file_entries, outside_entries, attempted_outside_rows, session_summaries, num_pairs).
    file_entries are keyed by relative file path within each pair's wd.
    """
    jsonl_files = sorted(run_dir.glob("pairs/*/flare*/wd/agent_output.jsonl"))
    if not jsonl_files:
        return [], [], [], [], 0

    inside_accum: dict[str, list[int]] = defaultdict(list)
    outside_rows: list[dict] = []
    attempted_outside_rows: list[dict] = []
    session_summaries: list[dict] = []

    for jf in jsonl_files:
        pair = jf.parts[-4]  # pairs/<pair>/flare/wd/agent_output.jsonl
        inside, outside, attempted_outside, summary = parse_trace(jf)
        for e in inside:
            inside_accum[e["file_path"]].extend(
                [e["total_chars"] // e["read_count"]] * e["read_count"]
            )
        for e in outside:
            outside_rows.append({**e, "pair": pair})
        for e in attempted_outside:
            attempted_outside_rows.append({**e, "pair": pair})
        if summary:
            session_summaries.append(summary)

    inside_entries = [
        {
            "file_path": fp,
            "read_count": len(cs),
            "total_chars": sum(cs),
            "total_tokens": sum(estimate_tokens(c) for c in cs),
        }
        for fp, cs in inside_accum.items()
    ]
    inside_entries.sort(key=lambda r: r["total_tokens"], reverse=True)
    outside_rows.sort(key=lambda r: (r["pair"], r["file_path"]))
    attempted_outside_rows.sort(key=lambda r: (r["pair"], r["file_path"]))
    return (
        inside_entries,
        outside_rows,
        attempted_outside_rows,
        session_summaries,
        len(jsonl_files),
    )


def fmt_int(n: int) -> str:
    return f"{n:,}"


def _print_table(entries: list[dict]) -> None:
    if not entries:
        print("  (none)")
        return
    col_w = max(len(e["file_path"]) for e in entries)
    col_w = max(col_w, 9)
    header = f"{'File path':<{col_w}}  {'Reads':>5}  {'Chars':>10}  {'~Tokens':>9}"
    sep = "-" * len(header)
    print(header)
    print(sep)
    for e in entries:
        print(
            f"{e['file_path']:<{col_w}}  "
            f"{e['read_count']:>5}  "
            f"{fmt_int(e['total_chars']):>10}  "
            f"{fmt_int(e['total_tokens']):>9}"
        )
    print(sep)
    label = f"TOTAL ({len(entries)} files)"
    print(
        f"{label:<{col_w}}  "
        f"{sum(e['read_count'] for e in entries):>5}  "
        f"{fmt_int(sum(e['total_chars'] for e in entries)):>10}  "
        f"{fmt_int(sum(e['total_tokens'] for e in entries)):>9}"
    )


def _print_session_stats(summaries: list[dict]) -> None:
    total_cost = sum(s.get("total_cost_usd", 0) for s in summaries)
    total_duration_ms = sum(s.get("duration_ms", 0) for s in summaries)
    total_turns = sum(s.get("num_turns", 0) for s in summaries)
    model_costs: dict[str, float] = defaultdict(float)
    usage_totals: dict[str, int] = defaultdict(int)
    for s in summaries:
        for model, mu in s.get("modelUsage", {}).items():
            model_costs[model] += mu.get("costUSD", 0)
        u = s.get("usage", {})
        for k in (
            "input_tokens",
            "output_tokens",
            "cache_creation_input_tokens",
            "cache_read_input_tokens",
        ):
            usage_totals[k] += u.get(k, 0)

    print(f"  Total cost:          ${total_cost:.4f}")
    print(f"  Duration:            {total_duration_ms / 1000:.1f}s")
    print(f"  Turns:               {fmt_int(total_turns)}")
    print(f"  API input tokens:    {fmt_int(usage_totals['input_tokens'])}")
    print(f"  API output tokens:   {fmt_int(usage_totals['output_tokens'])}")
    print(
        f"  Cache created:       {fmt_int(usage_totals['cache_creation_input_tokens'])}"
    )
    print(f"  Cache read:          {fmt_int(usage_totals['cache_read_input_tokens'])}")
    if model_costs:
        print("  Per-model cost:")
        for model, cost in sorted(model_costs.items()):
            print(f"    {model}: ${cost:.4f}")


def _print_attempted_table(entries: list[dict]) -> None:
    if not entries:
        print("  (none)")
        return
    col_w = max(len(e["file_path"]) for e in entries)
    col_w = max(col_w, 9)
    header = f"{'File path':<{col_w}}  {'Attempts':>8}"
    sep = "-" * len(header)
    print(header)
    print(sep)
    for e in entries:
        print(f"{e['file_path']:<{col_w}}  {e['attempt_count']:>8}")
    print(sep)


def _print_attempted_outside_table(rows: list[dict]) -> None:
    if not rows:
        return
    agg: dict[str, dict] = {}
    for r in rows:
        fp = r["file_path"]
        if fp not in agg:
            agg[fp] = {"attempt_count": 0, "pairs": []}
        agg[fp]["attempt_count"] += r["attempt_count"]
        agg[fp]["pairs"].append(r["pair"])
    aggregated = sorted(agg.items(), key=lambda x: x[1]["attempt_count"], reverse=True)
    display = [(fp, _display_outside_path(fp), v) for fp, v in aggregated]

    path_w = max(len(disp) for _, disp, _ in display)
    path_w = max(path_w, 9)
    pairs_w = max(len(", ".join(v["pairs"])) for _, _, v in display)
    pairs_w = max(pairs_w, 5)
    header = f"{'File path':<{path_w}}  {'Attempts':>8}  {'Pairs':<{pairs_w}}"
    sep = "-" * len(header)
    print(header)
    print(sep)
    for _, disp, v in display:
        print(
            f"{disp:<{path_w}}  "
            f"{v['attempt_count']:>8}  "
            f"{', '.join(v['pairs']):<{pairs_w}}"
        )
    print(sep)


def print_single(
    inside: list[dict],
    outside: list[dict],
    attempted_outside: list[dict],
    summary: dict,
    jsonl_path: Path,
) -> None:
    print(f"File: {jsonl_path}")
    print()
    _print_table(inside)
    if outside:
        print()
        print("!! Files accessed OUTSIDE working directory !!")
        _print_table(outside)
    if attempted_outside:
        print()
        print("!! Attempted OUTSIDE working directory access (denied) !!")
        _print_attempted_table(attempted_outside)
    if summary:
        print()
        print("Session stats:")
        _print_session_stats([summary])


def _display_outside_path(path_str: str) -> str:
    try:
        return str(Path(path_str).relative_to(_REPO_ROOT))
    except ValueError:
        return path_str


def _print_outside_table(rows: list[dict]) -> None:
    if not rows:
        return
    # aggregate by file_path
    agg: dict[str, dict] = {}
    for r in rows:
        fp = r["file_path"]
        if fp not in agg:
            agg[fp] = {
                "read_count": 0,
                "total_chars": 0,
                "total_tokens": 0,
                "pairs": [],
            }
        agg[fp]["read_count"] += r["read_count"]
        agg[fp]["total_chars"] += r["total_chars"]
        agg[fp]["total_tokens"] += r["total_tokens"]
        agg[fp]["pairs"].append(r["pair"])
    aggregated = sorted(agg.items(), key=lambda x: x[1]["total_tokens"], reverse=True)
    display = [(fp, _display_outside_path(fp), v) for fp, v in aggregated]

    path_w = max(len(disp) for _, disp, _ in display)
    path_w = max(path_w, 9)
    pairs_w = max(len(", ".join(v["pairs"])) for _, _, v in display)
    pairs_w = max(pairs_w, 5)
    header = f"{'File path':<{path_w}}  {'Reads':>5}  {'Chars':>10}  {'~Tokens':>9}  {'Pairs':<{pairs_w}}"
    sep = "-" * len(header)
    print(header)
    print(sep)
    for _, disp, v in display:
        print(
            f"{disp:<{path_w}}  "
            f"{v['read_count']:>5}  "
            f"{fmt_int(v['total_chars']):>10}  "
            f"{fmt_int(v['total_tokens']):>9}  "
            f"{', '.join(v['pairs']):<{pairs_w}}"
        )
    print(sep)


def print_run(
    inside: list[dict],
    outside: list[dict],
    attempted_outside: list[dict],
    summaries: list[dict],
    num_pairs: int,
    run_dir: Path,
) -> None:
    print(f"Run: {run_dir}  ({num_pairs} pairs)")
    print()
    _print_table(inside)
    if outside:
        print()
        print("!! Files accessed OUTSIDE working directory !!")
        _print_outside_table(outside)
    if attempted_outside:
        print()
        print("!! Attempted OUTSIDE working directory access (denied) !!")
        _print_attempted_outside_table(attempted_outside)
    if summaries:
        print()
        print(f"Aggregate session stats ({len(summaries)} sessions):")
        _print_session_stats(summaries)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "jsonl",
        nargs="*",
        type=Path,
        metavar="JSONL",
        help="agent_output.jsonl file(s)",
    )
    parser.add_argument(
        "-r", "--run", type=Path, metavar="RUN_DIR", help="Run directory to aggregate"
    )
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    if not args.run and not args.jsonl:
        parser.error("provide JSONL file(s) or -r RUN_DIR")

    if args.run:
        run_dir = args.run
        if not run_dir.exists():
            # try resolving as a run ID under <repo>/runs/
            candidate = Path(__file__).parent.parent / "runs" / run_dir
            if candidate.exists():
                run_dir = candidate
        if not run_dir.exists():
            print(f"Error: {run_dir} not found", file=sys.stderr)
            sys.exit(1)
        inside, outside, attempted_outside, summaries, num_pairs = aggregate_run(
            run_dir
        )
        if args.json:
            print(
                json.dumps(
                    {
                        "run": str(run_dir),
                        "num_pairs": num_pairs,
                        "reads": inside,
                        "outside_reads": outside,
                        "attempted_outside_reads": attempted_outside,
                        "sessions": summaries,
                    },
                    indent=2,
                )
            )
        else:
            print_run(inside, outside, attempted_outside, summaries, num_pairs, run_dir)
    else:
        output = []
        for path in args.jsonl:
            if not path.exists():
                print(f"Error: {path} not found", file=sys.stderr)
                sys.exit(1)
            inside, outside, attempted_outside, summary = parse_trace(path)
            if args.json:
                output.append(
                    {
                        "file": str(path),
                        "reads": inside,
                        "outside_reads": outside,
                        "attempted_outside_reads": attempted_outside,
                        "session": summary,
                    }
                )
            else:
                if len(args.jsonl) > 1:
                    print("=" * 80)
                print_single(inside, outside, attempted_outside, summary, path)
                if len(args.jsonl) > 1:
                    print()
        if args.json:
            print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
