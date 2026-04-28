#!/usr/bin/env python3
"""
Plot a horizontal Gantt-style chart showing how each pair's agent spent its time.

Each row = one pair; the x-axis is wall-clock time (seconds from first tool
result), derived from user-event timestamps in the JSONL. Bars are colored by
activity category:

  read   – Read tool or Bash commands that read/list files
  write  – Write / Edit
  lean   – anything lean_lsp
  skills – Skill / ToolSearch / Agent
  other  – everything else

Requires agent_action_log.py to have been run first to generate the CSVs.

Usage:
    python scripts/plot_agent_time.py 20260428T153758Z
"""

import argparse
import re
import sys
from pathlib import Path

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import pandas as pd

# ── category assignment ───────────────────────────────────────────────────────

CATEGORIES = {
    "lean": "#e05c5c",
    "write": "#5b8dd9",
    "read": "#5bb878",
    "skills": "#f0a030",
    "other": "#aaaaaa",
}


def categorize(tool_group: str, tool_name: str, tool_input: str) -> str:
    if tool_group == "lean_lsp":
        return "lean"
    if tool_name in ("Write", "Edit"):
        return "write"
    if tool_name in ("Read", "Glob", "Grep"):
        return "read"
    if tool_group == "bash":
        inp = str(tool_input).lower()
        # bash reads: cat / head / tail / ls / find / grep
        if re.search(r"\b(cat|head|tail|ls|find|grep|less|more)\b", inp):
            return "read"
        return "other"
    if tool_name in ("Skill", "ToolSearch", "Agent"):
        return "skills"
    return "other"


# ── main ──────────────────────────────────────────────────────────────────────


def load_pair(csv_path: Path) -> pd.DataFrame:
    df = pd.read_csv(csv_path)
    df["category"] = df.apply(
        lambda r: categorize(
            str(r.get("tool_group", "")),
            str(r.get("tool_name", "")),
            str(r.get("tool_input", "")),
        ),
        axis=1,
    )
    # x-axis: wall-clock seconds derived from timestamps
    # start_ms / end_ms are ms since the first tool result in this pair's session
    df["x_start"] = pd.to_numeric(df["start_ms"], errors="coerce").fillna(0) / 1000.0
    df["x_width"] = pd.to_numeric(df["duration_ms"], errors="coerce").fillna(0) / 1000.0
    # drop zero-width rows (unmeasured first call) — they'd be invisible anyway
    df = df[df["x_width"] > 0].copy()
    return df


def pair_label(stem: str) -> str:
    # p1_a__p1_b -> p1: a vs b
    m = re.match(r"(p\d+)_([a-z]+)__p\d+_([a-z]+)", stem)
    if m:
        return f"{m.group(1)}: {m.group(2)} vs {m.group(3)}"
    return stem


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_id", help="Run timestamp, e.g. 20260428T153758Z")
    args = parser.parse_args()

    repo_root = Path(__file__).parent.parent
    agent_time_dir = repo_root / "runs" / args.run_id / "analysis" / "agent_time"
    out_path = agent_time_dir / "summary.png"

    csv_files = sorted(
        [p for p in agent_time_dir.glob("p*.csv")],
        key=lambda p: (
            int(re.search(r"p(\d+)", p.stem).group(1)),
            p.stem,
        ),
    )
    if not csv_files:
        print(f"No pair CSVs found in {agent_time_dir}", file=sys.stderr)
        sys.exit(1)

    pairs = [(pair_label(p.stem), load_pair(p)) for p in csv_files]

    n = len(pairs)
    fig_h = max(4, n * 0.35)
    fig, ax = plt.subplots(figsize=(16, fig_h))

    for row_idx, (label, df) in enumerate(pairs):
        y = n - 1 - row_idx  # top-to-bottom order
        for _, r in df.iterrows():
            color = CATEGORIES[r["category"]]
            ax.barh(
                y,
                r["x_width"],
                left=r["x_start"],
                height=0.7,
                color=color,
                linewidth=0,
            )

    ax.set_yticks(range(n))
    ax.set_yticklabels([label for label, _ in reversed(pairs)], fontsize=7)
    ax.set_xlabel("Wall-clock time (seconds from first tool result)")
    ax.set_title(f"Agent time breakdown — run {args.run_id}")

    legend_patches = [
        mpatches.Patch(color=c, label=cat.capitalize())
        for cat, c in CATEGORIES.items()
    ]
    ax.legend(handles=legend_patches, loc="lower right", fontsize=8)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    plt.tight_layout()
    fig.savefig(out_path, dpi=150)
    print(f"Saved {out_path}")


if __name__ == "__main__":
    main()
