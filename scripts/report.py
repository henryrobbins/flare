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

if args.instance:
    header = f"  {'Method':<18} {'Pair':<20} {'GT':>4} {'Pred':>6} {'Err':>4}"
    print(header)
    print("  " + "-" * (len(header) - 2))
    for r in rows:
        method = r["method"]
        pair = f"{r['problem_a']}.{r['formulation_a']} / {r['problem_b']}.{r['formulation_b']}"
        gt = r["ground_truth"]
        pred = r.get("is_equivalent")
        err = r.get("error")
        is_error = bool(err) or pred is None
        is_wrong = not is_error and pred != gt
        if not args.verbose and not is_error and not is_wrong:
            continue
        gt_str = "T" if gt else "F"
        pred_str = ("T" if pred else "F") if not is_error else "-"
        err_str = "Y" if err else "N"
        print(f"  {method:<18} {pair:<20} {gt_str:>4} {pred_str:>6} {err_str:>4}")
else:
    stats = defaultdict(lambda: {"tp": 0, "fp": 0, "tn": 0, "fn": 0})
    for r in rows:
        method = r["method"]
        gt = r["ground_truth"]
        pred = r.get("is_equivalent")
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

    methods = sorted(stats)
    header = f"  {'Method':<18} {'TP':>4} {'FP':>4} {'TN':>4} {'FN':>4} {'Prec':>7} {'Rec':>7} {'F1':>7} {'Acc':>7}"
    print(header)
    print("  " + "-" * (len(header) - 2))
    for m in methods:
        s = stats[m]
        tp, fp, tn, fn = s["tp"], s["fp"], s["tn"], s["fn"]
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec  = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1   = 2 * prec * rec / (prec + rec) if (prec + rec) > 0 else 0.0
        acc  = (tp + tn) / (tp + fp + tn + fn) if (tp + fp + tn + fn) > 0 else 0.0
        print(f"  {m:<18} {tp:>4} {fp:>4} {tn:>4} {fn:>4} {prec:>7.3f} {rec:>7.3f} {f1:>7.3f} {acc:>7.3f}")
