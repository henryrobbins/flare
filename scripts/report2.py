#!/usr/bin/env python3
"""Classification metrics report aggregated across multiple runs.

Same as report.py but aggregates across the `run` field in results.jsonl:
- TP/FP/TN/FN are summed across runs.
- Precision, Recall, Accuracy are averaged across runs (mean ± std).
- AvgTime / AvgCost averaged across all (run, instance) entries.
"""

import argparse
import json
import math
from collections import defaultdict

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("-r", "--run-id", required=True, help="Run ID (e.g. 20260425T200341Z)")
parser.add_argument("-m", "--methods", nargs="+", help="Filter to specific methods")
parser.add_argument(
    "-p",
    "--problems",
    type=lambda s: [
        p.strip() if p.strip().startswith("p") else f"p{p.strip()}"
        for p in s.split(",")
        if p.strip()
    ],
    help="Filter to specific problems (comma-separated, e.g. 10,12)",
)
parser.add_argument(
    "-g",
    "--group-by",
    choices=["none", "model", "mode"],
    default="none",
    help="Aggregate rows by model or mode (default: none — one row per method)",
)
parser.add_argument(
    "-i",
    "--instance",
    action="store_true",
    help="Show per-instance results instead of summary",
)
parser.add_argument(
    "-v",
    "--verbose",
    action="store_true",
    help="Show all instances (default: errors only, with -i)",
)
args = parser.parse_args()

# Known mode labels used in experiment2.py. Used to split method names of the
# form llm_<model>[_reasoning]_<mode> when --group-by is set.
KNOWN_MODES = {
    "regular",
    "no_definition",
    "no_construction",
    "allow_implicit",
    "only_explicit",
    "naive",
}


def parse_method(name: str) -> tuple[str, str]:
    """Return (model_label, mode_label) parsed from a method name like
    'llm_opus_reasoning_regular'. The model label retains any '_reasoning'
    suffix so reasoning vs. non-reasoning are kept as distinct models."""
    body = name.removeprefix("llm_")
    for mode in KNOWN_MODES:
        if body.endswith("_" + mode):
            return body[: -len(mode) - 1], mode
    return body, "?"


def group_key(method: str) -> str:
    if args.group_by == "none":
        return method
    model, mode = parse_method(method)
    return model if args.group_by == "model" else mode

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
    pw = max(
        (
            len(
                f"{r['problem_a']}.{r['formulation_a']} / {r['problem_b']}.{r['formulation_b']}"
            )
            for r in rows
        ),
        default=4,
    )
    pw = max(pw, len("Pair"))
    header = (
        f"  {'Method':<{mw}} {'Run':>4} {'Pair':<{pw}} {'GT':>4} {'Pred':>6} "
        f"{'Err':>4} {'Time':>8} {'Cost':>8}"
    )
    print(header)
    print("  " + "-" * (len(header) - 2))
    for r in sorted(
        rows,
        key=lambda x: (
            x["method"],
            x.get("run", 1),
            x["problem_a"],
            x["formulation_a"],
            x["problem_b"],
            x["formulation_b"],
        ),
    ):
        method = r["method"]
        run_idx = r.get("run", 1)
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
        print(
            f"  {method:<{mw}} {run_idx:>4} {pair:<{pw}} {gt_str:>4} {pred_str:>6} "
            f"{err_str:>4} {time_str:>8} {cost_str:>8}"
        )
    raise SystemExit(0)


def mean_std(xs: list[float]) -> tuple[float, float]:
    if not xs:
        return 0.0, 0.0
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return m, 0.0
    var = sum((x - m) ** 2 for x in xs) / (len(xs) - 1)
    return m, math.sqrt(var)


# Group by (method, run): per-run TP/FP/TN/FN.
per_run: dict[tuple[str, int], dict] = defaultdict(
    lambda: {"tp": 0, "fp": 0, "tn": 0, "fn": 0}
)
# Per method: total TP/FP/TN/FN summed across runs, and time/cost samples.
totals: dict[str, dict] = defaultdict(
    lambda: {
        "tp": 0,
        "fp": 0,
        "tn": 0,
        "fn": 0,
        "duration_sum": 0.0,
        "duration_n": 0,
        "cost_sum": 0.0,
        "cost_n": 0,
        "runs": set(),
    }
)

for r in rows:
    key = group_key(r["method"])
    gt = r["ground_truth"]
    pred = r.get("is_reformulation")
    err = r.get("error")
    run_idx = r.get("run", 1)

    totals[key]["runs"].add(run_idx)

    if r.get("duration_s") is not None:
        totals[key]["duration_sum"] += r["duration_s"]
        totals[key]["duration_n"] += 1
    if r.get("cost_usd") is not None:
        totals[key]["cost_sum"] += r["cost_usd"]
        totals[key]["cost_n"] += 1

    if err or pred is None:
        continue

    if pred and gt:
        bucket = "tp"
    elif pred and not gt:
        bucket = "fp"
    elif not pred and not gt:
        bucket = "tn"
    else:
        bucket = "fn"

    per_run[(key, run_idx)][bucket] += 1
    totals[key][bucket] += 1


def metrics(s: dict) -> tuple[float, float, float]:
    tp, fp, tn, fn = s["tp"], s["fp"], s["tn"], s["fn"]
    prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
    rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
    acc = (tp + tn) / (tp + fp + tn + fn) if (tp + fp + tn + fn) > 0 else 0.0
    return prec, rec, acc


label = {"none": "Method", "model": "Model", "mode": "Mode"}[args.group_by]
keys = sorted(totals)
mw = max((len(k) for k in keys), default=6)
mw = max(mw, len(label))
header = (
    f"  {label:<{mw}} {'#Runs':>5} {'TP':>4} {'FP':>4} {'TN':>4} {'FN':>4} "
    f"{'Prec':>15} {'Rec':>15} {'Acc':>15} {'AvgTime':>8} {'AvgCost':>9}"
)
print(header)
print("  " + "-" * (len(header) - 2))

for m in keys:
    s = totals[m]
    runs = sorted(s["runs"])
    n_runs = len(runs)

    precs, recs, accs = [], [], []
    for r_idx in runs:
        p, rc, ac = metrics(per_run[(m, r_idx)])
        precs.append(p)
        recs.append(rc)
        accs.append(ac)

    prec_m, prec_s = mean_std(precs)
    rec_m, rec_s = mean_std(recs)
    acc_m, acc_s = mean_std(accs)

    avg_time = fmt_duration(
        s["duration_sum"] / s["duration_n"] if s["duration_n"] else None
    )
    avg_cost = fmt_cost(s["cost_sum"] / s["cost_n"] if s["cost_n"] else None)

    prec_str = f"{prec_m:.3f}±{prec_s:.3f}"
    rec_str = f"{rec_m:.3f}±{rec_s:.3f}"
    acc_str = f"{acc_m:.3f}±{acc_s:.3f}"

    print(
        f"  {m:<{mw}} {n_runs:>5} {s['tp']:>4} {s['fp']:>4} {s['tn']:>4} {s['fn']:>4} "
        f"{prec_str:>15} {rec_str:>15} {acc_str:>15} {avg_time:>8} {avg_cost:>9}"
    )
