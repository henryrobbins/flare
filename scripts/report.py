#!/usr/bin/env python3
"""Classification metrics report per method for a given run."""

import argparse
import json
from collections import defaultdict

parser = argparse.ArgumentParser(description="Generate classification metrics report for a run.")
parser.add_argument("-r", "--run-id", required=True, help="Run ID (e.g. 20260425T200341Z)")
parser.add_argument("-m", "--methods", nargs="+", help="Filter to specific methods")
parser.add_argument("-p", "--problems", nargs="+", help="Filter to specific problems")
parser.add_argument("-i", "--instance", action="store_true", help="Show per-instance results instead of summary")
parser.add_argument("-v", "--verbose", action="store_true", help="Show all instances (default: errors only, with -i)")
args = parser.parse_args()

path = f"runs/{args.run_id}/results.jsonl"

rows = []
with open(path) as f:
    for line in f:
        r = json.loads(line)
        if args.methods and r["method"] not in args.methods:
            continue
        if args.problems and r["problem_a"] not in args.problems:
            continue
        rows.append(r)

def fmt_duration(s) -> str:
    if s is None:
        return "-"
    return f"{s:.1f}s"


def fmt_cost(c) -> str:
    if c is None:
        return "-"
    if c < 0.001:
        return f"${c:.4f}"
    return f"${c:.3f}"


if args.instance:
    mw = max((len(r["method"]) for r in rows), default=6)
    mw = max(mw, len("Method"))
    pw = max((len(f"{r['problem_a']}.{r['formulation_a']} / {r['problem_b']}.{r['formulation_b']}") for r in rows), default=4)
    pw = max(pw, len("Pair"))
    header = f"  {'Method':<{mw}} {'Pair':<{pw}} {'GT':>4} {'Pred':>6} {'Err':>4} {'Time':>8} {'Cost':>8}"
    print(header)
    print("  " + "-" * (len(header) - 2))
    for r in rows:
        method = r["method"]
        pair = f"{r['problem_a']}.{r['formulation_a']} / {r['problem_b']}.{r['formulation_b']}"
        gt = r["ground_truth"]
        pred = r.get("is_reformulation")
        err = r.get("error")
        is_error = bool(err) or pred is None
        is_wrong = not is_error and pred != gt
        if not args.verbose and not is_error and not is_wrong:
            continue
        gt_str = "T" if gt else "F"
        pred_str = ("T" if pred else "F") if not is_error else "-"
        err_str = "Y" if err else "N"
        time_str = fmt_duration(r.get("duration_s"))
        cost_str = fmt_cost(r.get("cost_usd"))
        print(f"  {method:<{mw}} {pair:<{pw}} {gt_str:>4} {pred_str:>6} {err_str:>4} {time_str:>8} {cost_str:>8}")
else:
    stats = defaultdict(lambda: {
        "tp": 0, "fp": 0, "tn": 0, "fn": 0,
        "duration_sum": 0.0, "duration_n": 0,
        "cost_sum": 0.0, "cost_n": 0,
    })
    for r in rows:
        method = r["method"]
        gt = r["ground_truth"]
        pred = r.get("is_reformulation")
        err = r.get("error")

        if err or pred is None:
            continue

        if pred and gt:
            stats[method]["tp"] += 1
        elif pred and not gt:
            stats[method]["fp"] += 1
        elif not pred and not gt:
            stats[method]["tn"] += 1
        else:
            stats[method]["fn"] += 1

        if r.get("duration_s") is not None:
            stats[method]["duration_sum"] += r["duration_s"]
            stats[method]["duration_n"] += 1
        if r.get("cost_usd") is not None:
            stats[method]["cost_sum"] += r["cost_usd"]
            stats[method]["cost_n"] += 1

    methods = sorted(stats)
    mw = max((len(m) for m in methods), default=6)
    mw = max(mw, len("Method"))
    header = f"  {'Method':<{mw}} {'TP':>4} {'FP':>4} {'TN':>4} {'FN':>4} {'Prec':>7} {'Rec':>7} {'F1':>7} {'Acc':>7} {'AvgTime':>8} {'AvgCost':>9}"
    print(header)
    print("  " + "-" * (len(header) - 2))
    for m in methods:
        s = stats[m]
        tp, fp, tn, fn = s["tp"], s["fp"], s["tn"], s["fn"]
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec  = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1   = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0.0
        acc  = (tp + tn) / (tp + fp + tn + fn) if (tp + fp + tn + fn) > 0 else 0.0
        avg_time = fmt_duration(s["duration_sum"] / s["duration_n"] if s["duration_n"] else None)
        avg_cost = fmt_cost(s["cost_sum"] / s["cost_n"] if s["cost_n"] else None)
        print(f"  {m:<{mw}} {tp:>4} {fp:>4} {tn:>4} {fn:>4} {prec:>7.3f} {rec:>7.3f} {f1:>7.3f} {acc:>7.3f} {avg_time:>8} {avg_cost:>9}")
