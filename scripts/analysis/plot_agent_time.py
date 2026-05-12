#!/usr/bin/env python3
"""Horizontal Gantt-style chart of how each artifact dir spent its time.

One row per (pair, artifact_dir). X-axis is wall-clock seconds from session
start; bars are colored by tool_group. Artifacts whose JSONL carries no
timestamps (e.g. codex) appear as a thin marker showing "no timing".

Usage:
    python scripts/analysis/plot_agent_time.py -r 20260512T050406Z
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from src.analysis.agent_jsonl import discover_artifacts, read_log_csv, write_log_csv


GROUP_COLORS = {
    "lean_lsp": "#e05c5c",
    "file_io": "#5bb878",
    "bash": "#aaaaaa",
    "agent": "#f0a030",
    "skill": "#9b5bd9",
    "web": "#5b8dd9",
    "other": "#cccccc",
}


def _int(s) -> int:
    try:
        return int(s)
    except (TypeError, ValueError):
        return 0


def _label(artifact_dir: Path) -> str:
    pair = artifact_dir.parent.name
    art = artifact_dir.name
    m = re.match(r"(p\d+)_([a-z]+)__p\d+_([a-z]+)", pair)
    if m:
        pair = f"{m.group(1)}: {m.group(2)} vs {m.group(3)}"
    return f"{pair}  [{art}]"


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("-r", "--run-id", required=True)
    p.add_argument("-o", "--out", type=Path, help="Output PNG (default: runs/<id>/agent_time.png)")
    args = p.parse_args()

    run_dir = Path("runs") / args.run_id
    artifacts = discover_artifacts(run_dir)
    if not artifacts:
        sys.exit(f"No artifact dirs found under {run_dir}")

    rows_per: list[tuple[str, list[dict]]] = []
    for d in artifacts:
        rows = read_log_csv(write_log_csv(d))
        bars = [
            r
            for r in rows
            if r["event_type"] == "tool_call" and _int(r.get("duration_ms")) > 0
        ]
        rows_per.append((_label(d), bars))

    n = len(rows_per)
    fig_h = max(4, n * 0.6)
    fig, ax = plt.subplots(figsize=(16, fig_h))

    for row_idx, (label, bars) in enumerate(rows_per):
        y = n - 1 - row_idx
        if not bars:
            ax.text(0, y, "(no timing)", va="center", fontsize=8, color="#888")
            continue
        for r in bars:
            start = _int(r.get("start_ms")) / 1000.0
            width = _int(r.get("duration_ms")) / 1000.0
            color = GROUP_COLORS.get(r.get("tool_group", "other"), GROUP_COLORS["other"])
            ax.barh(y, width, left=start, height=0.7, color=color, linewidth=0)

    ax.set_yticks(range(n))
    ax.set_yticklabels([lbl for lbl, _ in reversed(rows_per)], fontsize=7)
    ax.set_xlabel("Wall-clock time (seconds from session start)")
    ax.set_title(f"Agent time breakdown — run {args.run_id}")
    ax.legend(
        handles=[mpatches.Patch(color=c, label=g) for g, c in GROUP_COLORS.items()],
        loc="lower right",
        fontsize=8,
    )
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout()

    out = args.out or (run_dir / "agent_time.png")
    fig.savefig(out, dpi=150)
    print(f"Saved {out}")


if __name__ == "__main__":
    main()
