"""Convert per-agent JSONL traces into a single standard CSV schema.

Each FLARE harness (claude_code, codex, opencode) emits its own JSONL stream
shape. This module normalizes them into one row-per-event CSV so the
downstream analysis scripts (scripts/analysis/*) can be agent-agnostic.

Schema (`agent_log.csv` columns):

    index, event_type, start_ms, end_ms, duration_ms,
    tool_name, tool_group, tool_input, target_path, output_chars, is_error,
    input_tokens, output_tokens, cache_create_tokens, cache_read_tokens,
    reasoning_tokens, cost_usd, model

`event_type` is `model_turn` or `tool_call`. Token/cost columns are only
populated on `model_turn` rows; tool-related columns only on `tool_call`
rows. Cells that the source trace doesn't carry are left empty.

Timestamps are ms since the first observed event; agents that don't emit
timestamps (codex) leave the three time columns blank.
"""

from __future__ import annotations

import csv
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Iterable

CSV_FIELDS = [
    "index",
    "event_type",
    "start_ms",
    "end_ms",
    "duration_ms",
    "tool_name",
    "tool_group",
    "tool_input",
    "target_path",
    "output_chars",
    "is_error",
    "input_tokens",
    "output_tokens",
    "cache_create_tokens",
    "cache_read_tokens",
    "reasoning_tokens",
    "cost_usd",
    "model",
]

# Path inside the container where each pair's wd is bind-mounted. All
# absolute paths in agent traces are rooted here.
CONTAINER_WD = "/workspace/wd"


# ── tool grouping ─────────────────────────────────────────────────────────────


def _tool_group(name: str) -> str:
    if name.startswith("lean_"):
        return "lean_lsp"
    if name in ("read", "write", "edit", "glob", "grep", "file_change"):
        return "file_io"
    if name == "bash":
        return "bash"
    if name in ("task", "agent", "subagent", "toolsearch"):
        return "agent"
    if name == "skill":
        return "skill"
    if name in ("webfetch", "websearch", "web_search", "web_fetch"):
        return "web"
    return "other"


def _strip_wd(path: str) -> str:
    """Render a path relative to the agent wd."""
    if not path:
        return ""
    if path.startswith(CONTAINER_WD + "/"):
        return path[len(CONTAINER_WD) + 1 :]
    if path == CONTAINER_WD:
        return ""
    if path.startswith("./"):
        return path[2:]
    return path


def _truncate(s: str, n: int = 160) -> str:
    s = (s or "").replace("\n", " ").strip()
    return s if len(s) <= n else s[: n - 1] + "…"


# Used to detect file paths in bash commands so codex's `sed`/`cat`/etc.
# file reads get a target_path. We only attribute when the command references
# a single unique file (avoids misattributing multi-file commands like
# `wc -l A B C`, whose tiny output isn't meaningful for context anyway).
_FILE_EXTS = (
    ".lean", ".md", ".py", ".toml", ".json", ".sh",
    ".yaml", ".yml", ".txt", ".csv",
)
_BASH_FILE_RE = re.compile(
    r"(?:^|[\s'\"<>|;&()])"
    r"((?:/|\./|[A-Za-z0-9_.-]+/)?[A-Za-z0-9_./-]+(?:"
    + "|".join(re.escape(e) for e in _FILE_EXTS)
    + r"))(?=[\s'\"<>|;&()]|$)"
)


def _bash_target(cmd: str) -> str:
    if not cmd:
        return ""
    matches = {_strip_wd(m) for m in _BASH_FILE_RE.findall(cmd)}
    if len(matches) == 1:
        return next(iter(matches))
    return ""


def _empty_row(index: int) -> dict:
    return {k: "" for k in CSV_FIELDS} | {"index": index}


# ── claude_code ───────────────────────────────────────────────────────────────


def _canon_claude_tool(name: str) -> str:
    if name.startswith("mcp__lean-lsp__"):
        return name[len("mcp__lean-lsp__") :]
    return name.lower()


def _claude_tool_input(name: str, inp: dict) -> tuple[str, str]:
    """Return (tool_input_summary, target_path)."""
    canon = _canon_claude_tool(name)
    if name in ("Read", "Write", "Edit"):
        path = _strip_wd(inp.get("file_path", ""))
        return path, path
    if name == "Bash":
        cmd = inp.get("command", "")
        return _truncate(cmd), _bash_target(cmd)
    if name == "Glob":
        return inp.get("pattern", ""), ""
    if name == "Grep":
        pat = inp.get("pattern", "")
        path = _strip_wd(inp.get("path", ""))
        return _truncate(f"{pat}  in  {path}" if path else pat), path
    if name in ("Skill",):
        return inp.get("skill", ""), ""
    if name in ("ToolSearch",):
        return inp.get("query", ""), ""
    if name in ("Agent", "Task"):
        return inp.get("description", ""), ""
    if canon.startswith("lean_"):
        path = _strip_wd(inp.get("file_path", ""))
        line = inp.get("line")
        loc = f"{path}:{line}" if path and line is not None else path
        return loc or _truncate(inp.get("code", "") or ""), path
    # generic fallback
    for v in inp.values():
        if isinstance(v, str):
            return _truncate(v), ""
    return "", ""


def _claude_content_chars(content) -> int:
    if isinstance(content, str):
        return len(content)
    if isinstance(content, list):
        return sum(
            len(c.get("text", "")) if isinstance(c, dict) else 0 for c in content
        )
    return 0


def _parse_claude_code(events: list[dict]) -> list[dict]:
    # Map tool_use_id -> {ts_end (datetime), is_error, output_chars}.
    # claude_code's stream-json puts timestamps only on user events (which
    # carry tool_results), not on assistant events. So tool_call rows get
    # times; model_turn rows leave them blank.
    tool_results: dict[str, dict] = {}
    t0: datetime | None = None
    for e in events:
        if e.get("type") != "user":
            continue
        ts = e.get("timestamp")
        ts_dt = datetime.fromisoformat(ts.replace("Z", "+00:00")) if ts else None
        if ts_dt is not None and t0 is None:
            t0 = ts_dt
        for c in e.get("message", {}).get("content", []):
            if c.get("type") == "tool_result":
                tool_results[c.get("tool_use_id", "")] = {
                    "ts_end": ts_dt,
                    "is_error": bool(c.get("is_error", False)),
                    "output_chars": _claude_content_chars(c.get("content")),
                }

    def rel_ms(dt: datetime | None) -> int | str:
        if dt is None or t0 is None:
            return ""
        return round((dt - t0).total_seconds() * 1000)

    rows: list[dict] = []
    prev_end_dt: datetime | None = None
    for e in events:
        if e.get("type") != "assistant":
            continue
        msg = e.get("message", {})
        usage = msg.get("usage") or {}
        model = msg.get("model", "")
        content = msg.get("content", [])
        tool_uses = [c for c in content if c.get("type") == "tool_use"]

        # model_turn row (no timing — claude doesn't timestamp assistant events)
        row = _empty_row(len(rows))
        row.update(
            {
                "event_type": "model_turn",
                "input_tokens": usage.get("input_tokens", "") or "",
                "output_tokens": usage.get("output_tokens", "") or "",
                "cache_create_tokens": usage.get("cache_creation_input_tokens", "")
                or "",
                "cache_read_tokens": usage.get("cache_read_input_tokens", "") or "",
                "model": model,
            }
        )
        rows.append(row)

        for tu in tool_uses:
            name = tu.get("name", "")
            canon = _canon_claude_tool(name)
            ti, target = _claude_tool_input(name, tu.get("input", {}) or {})
            res = tool_results.get(tu.get("id", ""), {})
            end_dt = res.get("ts_end")
            start_dt = prev_end_dt
            tool_row = _empty_row(len(rows))
            tool_row.update(
                {
                    "event_type": "tool_call",
                    "start_ms": rel_ms(start_dt) if start_dt else 0,
                    "end_ms": rel_ms(end_dt),
                    "duration_ms": (
                        rel_ms(end_dt) - (rel_ms(start_dt) if start_dt else 0)
                        if end_dt is not None
                        else ""
                    ),
                    "tool_name": canon,
                    "tool_group": _tool_group(canon),
                    "tool_input": ti,
                    "target_path": target,
                    "output_chars": res.get("output_chars", "") or "",
                    "is_error": res.get("is_error", False),
                }
            )
            rows.append(tool_row)
            if end_dt is not None:
                prev_end_dt = end_dt

    # Total session cost lives on the result event; attach to the last
    # model_turn row so the summary aggregators pick it up.
    result = next((e for e in events if e.get("type") == "result"), None)
    if result is not None:
        total_cost = result.get("total_cost_usd")
        if total_cost is not None:
            for r in reversed(rows):
                if r["event_type"] == "model_turn":
                    r["cost_usd"] = total_cost
                    break

    return rows


# ── codex ─────────────────────────────────────────────────────────────────────


def _codex_content_chars(item: dict) -> int:
    t = item.get("type")
    if t == "command_execution":
        return len(item.get("aggregated_output", "") or "")
    if t == "mcp_tool_call":
        result = item.get("result") or {}
        parts = result.get("content") or []
        return sum(
            len(p.get("text", "")) if isinstance(p, dict) else 0 for p in parts
        )
    return 0


def _codex_tool_input(item: dict) -> tuple[str, str, str, str]:
    """Return (tool_name, tool_group, tool_input, target_path)."""
    t = item.get("type")
    if t == "mcp_tool_call":
        name = item.get("tool", "") or ""
        args = item.get("arguments") or {}
        path = _strip_wd(args.get("file_path", "") or "")
        line = args.get("line")
        loc = f"{path}:{line}" if path and line is not None else path
        ti = loc or _truncate(json.dumps(args)) if args else ""
        return name, _tool_group(name), ti, path
    if t == "command_execution":
        cmd = item.get("command", "")
        return "bash", "bash", _truncate(cmd), _bash_target(cmd)
    if t == "file_change":
        path = _strip_wd(item.get("path", "") or "")
        return "file_change", "file_io", path, path
    return "", "other", "", ""


def _parse_codex(events: list[dict]) -> list[dict]:
    rows: list[dict] = []
    # Codex traces don't carry timestamps; emit rows in sequence with empty times.
    for e in events:
        et = e.get("type")
        if et == "item.completed":
            item = e.get("item") or {}
            it = item.get("type")
            if it == "agent_message":
                # Skip — pure model text without a tool action.
                continue
            name, group, ti, target = _codex_tool_input(item)
            if not name:
                continue
            is_err = bool(item.get("error")) or item.get("status") == "failed"
            row = _empty_row(len(rows))
            row.update(
                {
                    "event_type": "tool_call",
                    "tool_name": name,
                    "tool_group": group,
                    "tool_input": ti,
                    "target_path": target,
                    "output_chars": _codex_content_chars(item),
                    "is_error": is_err,
                }
            )
            rows.append(row)
        elif et == "turn.completed":
            usage = e.get("usage") or {}
            inp = int(usage.get("input_tokens", 0) or 0)
            cached = int(usage.get("cached_input_tokens", 0) or 0)
            out = int(usage.get("output_tokens", 0) or 0)
            reasoning = int(usage.get("reasoning_output_tokens", 0) or 0)
            row = _empty_row(len(rows))
            row.update(
                {
                    "event_type": "model_turn",
                    "input_tokens": inp - cached if inp >= cached else inp,
                    "output_tokens": out,
                    "cache_read_tokens": cached,
                    "reasoning_tokens": reasoning,
                }
            )
            rows.append(row)
    return rows


# ── opencode ──────────────────────────────────────────────────────────────────


def _canon_opencode_tool(name: str) -> str:
    # opencode names lean-lsp tools as `lean-lsp_lean_X`
    if name.startswith("lean-lsp_"):
        return name[len("lean-lsp_") :]
    return name.lower()


def _opencode_tool_input(name: str, inp: dict) -> tuple[str, str]:
    canon = _canon_opencode_tool(name)
    if name in ("read", "write", "edit"):
        path = _strip_wd(inp.get("filePath", "") or "")
        return path, path
    if name == "bash":
        cmd = inp.get("command", "") or ""
        return _truncate(cmd), _bash_target(cmd)
    if name == "skill":
        return inp.get("name", "") or "", ""
    if canon.startswith("lean_"):
        path = _strip_wd(inp.get("file_path", "") or "")
        line = inp.get("line")
        loc = f"{path}:{line}" if path and line is not None else path
        return loc or _truncate(inp.get("code", "") or ""), path
    for v in inp.values():
        if isinstance(v, str):
            return _truncate(v), ""
    return "", ""


def _parse_opencode(events: list[dict]) -> list[dict]:
    rows: list[dict] = []
    t0_ms: int | None = None
    prev_end_ms: int | None = None

    def rel(ms: int | None) -> int | str:
        if ms is None or t0_ms is None:
            return ""
        return ms - t0_ms

    for e in events:
        et = e.get("type")
        ts = e.get("timestamp")
        if isinstance(ts, int) and t0_ms is None:
            t0_ms = ts

        if et == "tool_use":
            part = e.get("part") or {}
            state = part.get("state") or {}
            if state.get("status") != "completed":
                continue
            name = part.get("tool", "") or ""
            canon = _canon_opencode_tool(name)
            ti, target = _opencode_tool_input(name, state.get("input") or {})
            output = state.get("output", "")
            if not isinstance(output, str):
                output = json.dumps(output) if output else ""
            is_err = bool(state.get("error"))
            end_ms = ts if isinstance(ts, int) else None
            start_ms = prev_end_ms if prev_end_ms is not None else end_ms
            row = _empty_row(len(rows))
            row.update(
                {
                    "event_type": "tool_call",
                    "start_ms": rel(start_ms),
                    "end_ms": rel(end_ms),
                    "duration_ms": (
                        rel(end_ms) - rel(start_ms)
                        if end_ms and start_ms and t0_ms is not None
                        else ""
                    ),
                    "tool_name": canon,
                    "tool_group": _tool_group(canon),
                    "tool_input": ti,
                    "target_path": target,
                    "output_chars": len(output),
                    "is_error": is_err,
                }
            )
            rows.append(row)
            if end_ms is not None:
                prev_end_ms = end_ms

        elif et == "step_finish":
            part = e.get("part") or {}
            tokens = part.get("tokens") or {}
            cache = tokens.get("cache") or {}
            end_ms = ts if isinstance(ts, int) else None
            start_ms = prev_end_ms if prev_end_ms is not None else end_ms
            row = _empty_row(len(rows))
            row.update(
                {
                    "event_type": "model_turn",
                    "start_ms": rel(start_ms),
                    "end_ms": rel(end_ms),
                    "duration_ms": (
                        rel(end_ms) - rel(start_ms)
                        if end_ms and start_ms and t0_ms is not None
                        else ""
                    ),
                    "input_tokens": int(tokens.get("input", 0) or 0),
                    "output_tokens": int(tokens.get("output", 0) or 0),
                    "cache_create_tokens": int(cache.get("write", 0) or 0),
                    "cache_read_tokens": int(cache.get("read", 0) or 0),
                    "reasoning_tokens": int(tokens.get("reasoning", 0) or 0),
                    "cost_usd": part.get("cost", "") or "",
                }
            )
            rows.append(row)
            if end_ms is not None:
                prev_end_ms = end_ms

    return rows


# ── dispatch + IO ─────────────────────────────────────────────────────────────


_PARSERS = {
    "claude_code": _parse_claude_code,
    "codex": _parse_codex,
    "opencode": _parse_opencode,
}


def parse(jsonl_path: Path, harness: str) -> list[dict]:
    if harness not in _PARSERS:
        raise ValueError(f"unknown harness: {harness}")
    events: list[dict] = []
    with jsonl_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return _PARSERS[harness](events)


def _read_harness(artifact_dir: Path) -> str:
    cfg_path = artifact_dir / "config.json"
    if not cfg_path.exists():
        raise FileNotFoundError(f"{cfg_path} not found")
    cfg = json.loads(cfg_path.read_text())
    harness = cfg.get("harness")
    if not harness:
        raise ValueError(f"{cfg_path} has no `harness` field")
    # Older runs prefixed harness names with `docker_` (e.g. `docker_codex`).
    # The JSONL format is identical, so normalize to the current names.
    if harness.startswith("docker_"):
        harness = harness[len("docker_") :]
    return harness


def write_log_csv(artifact_dir: Path, dest: Path | None = None) -> Path:
    """(Re)build agent_log.csv for an artifact dir."""
    harness = _read_harness(artifact_dir)
    jsonl_path = artifact_dir / "wd" / "agent_output.jsonl"
    rows = parse(jsonl_path, harness)
    out = dest or (artifact_dir / "agent_log.csv")
    with out.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=CSV_FIELDS)
        w.writeheader()
        w.writerows(rows)
    return out


def ensure_log_csv(artifact_dir: Path) -> Path:
    """Return artifact_dir/agent_log.csv, regenerating from JSONL if missing."""
    out = artifact_dir / "agent_log.csv"
    if not out.exists():
        write_log_csv(artifact_dir, out)
    return out


def read_log_csv(path: Path) -> list[dict]:
    with path.open() as fh:
        return list(csv.DictReader(fh))


def discover_artifacts(run_dir: Path) -> list[Path]:
    """Every directory containing wd/agent_output.jsonl under run_dir/pairs/*."""
    return sorted(
        p.parent.parent
        for p in run_dir.glob("pairs/*/*/wd/agent_output.jsonl")
    )


def iter_log_rows(artifact_dirs: Iterable[Path]) -> Iterable[tuple[Path, list[dict]]]:
    for d in artifact_dirs:
        yield d, read_log_csv(ensure_log_csv(d))


# ── CLI ───────────────────────────────────────────────────────────────────────


def main() -> None:
    import argparse

    p = argparse.ArgumentParser(
        description="(Re)generate agent_log.csv for one artifact dir or every dir in a run."
    )
    p.add_argument("-r", "--run-id", help="Run ID under runs/")
    p.add_argument("-d", "--artifact-dir", type=Path, help="Single artifact dir")
    p.add_argument("--force", action="store_true", help="Regenerate even if present")
    args = p.parse_args()

    targets: list[Path] = []
    if args.artifact_dir:
        targets = [args.artifact_dir]
    elif args.run_id:
        targets = discover_artifacts(Path("runs") / args.run_id)
    else:
        p.error("provide --run-id or --artifact-dir")

    for d in targets:
        out = d / "agent_log.csv"
        if args.force or not out.exists():
            write_log_csv(d, out)
            print(f"  wrote  {out}")
        else:
            print(f"  exists {out}")


if __name__ == "__main__":
    main()
