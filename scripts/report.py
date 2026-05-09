#!/usr/bin/env python3
"""Classification metrics report for an experiment run.

Reads `runs/{run_id}/results.jsonl` and prints either a per-instance table
(`-i`) or a summary aggregated across runs. When the JSONL contains a `run`
field, per-run Prec/Rec/Acc are reported as mean ± std; rows where `run` is
null are treated as a single run with no std suffix.

Mode/model labels come from the `model` and `mode` fields written by
experiments/utils.py. Use scripts/backfill_method_metadata.py to populate
these on historic results.jsonl files.
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
    "--modes",
    nargs="+",
    help="Filter to specific modes (e.g. regular naive). Applies only to rows with a non-null mode.",
)
parser.add_argument(
    "--models",
    nargs="+",
    help="Filter to specific models. Applies only to rows with a non-null model.",
)
parser.add_argument(
    "-g",
    "--group-by",
    choices=["none", "model", "mode"],
    default="none",
    help="Aggregate rows by model or mode (default: none — one row per method). "
    "Rows with null model/mode are excluded when grouping.",
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


path = f"runs/{args.run_id}/results.jsonl"

rows = []
with open(path) as f:
    for line in f:
        r = json.loads(line)
        if args.methods and r["method"] not in args.methods:
            continue
        if args.problems and r["problem_a"] not in args.problems:
            continue
        if args.modes and r.get("mode") is not None and r["mode"] not in args.modes:
            continue
        if args.models and r.get("model") is not None and r["model"] not in args.models:
            continue
        rows.append(r)


def group_key(r: dict) -> str | None:
    if args.group_by == "none":
        return r["method"]
    val = r.get(args.group_by)
    return val  # None → row excluded from grouped summary


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


def fmt_tokens(t) -> str:
    if t is None:
        return "-"
    return f"{t:,.0f}"


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
            x.get("run") or 0,
            x["problem_a"],
            x["formulation_a"],
            x["problem_b"],
            x["formulation_b"],
        ),
    ):
        method = r["method"]
        run_idx = r.get("run")
        run_str = "-" if run_idx is None else str(run_idx)
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
            f"  {method:<{mw}} {run_str:>4} {pair:<{pw}} {gt_str:>4} {pred_str:>6} "
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


# Group by (key, run): per-run TP/FP/TN/FN. For rows where run is null, we
# bucket under run_idx=None (treated as a single virtual run).
per_run: dict[tuple[str, int | None], dict] = defaultdict(
    lambda: {"tp": 0, "fp": 0, "tn": 0, "fn": 0}
)
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
        "in_tok_sum": 0.0,
        "in_tok_n": 0,
        "out_tok_sum": 0.0,
        "out_tok_n": 0,
        "rsn_tok_sum": 0.0,
        "rsn_tok_n": 0,
        "runs": set(),
        "had_null_run": False,
    }
)

for r in rows:
    key = group_key(r)
    if key is None:
        continue  # grouping by model/mode and this row has no value
    gt = r["ground_truth"]
    pred = r.get("is_reformulation")
    err = r.get("error")
    run_idx = r.get("run")

    if run_idx is None:
        totals[key]["had_null_run"] = True
    else:
        totals[key]["runs"].add(run_idx)

    if r.get("duration_s") is not None:
        totals[key]["duration_sum"] += r["duration_s"]
        totals[key]["duration_n"] += 1
    if r.get("cost_usd") is not None:
        totals[key]["cost_sum"] += r["cost_usd"]
        totals[key]["cost_n"] += 1
    for src, dst in [
        ("input_tokens", "in_tok"),
        ("output_tokens", "out_tok"),
        ("reasoning_tokens", "rsn_tok"),
    ]:
        v = r.get(src)
        if v is not None:
            totals[key][f"{dst}_sum"] += v
            totals[key][f"{dst}_n"] += 1

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
    f"{'Prec':>15} {'Rec':>15} {'Acc':>15} "
    f"{'AvgTime':>8} {'AvgCost':>9} {'AvgIn':>9} {'AvgOut':>9} {'AvgRsn':>9}"
)
print(header)
print("  " + "-" * (len(header) - 2))


def fmt_metric(m: float, s: float, with_std: bool) -> str:
    return f"{m:.3f}±{s:.3f}" if with_std else f"{m:.3f}"


for m in keys:
    s = totals[m]
    runs = sorted(s["runs"])
    if not runs and s["had_null_run"]:
        # All rows had run=None: treat as one virtual run.
        runs = [None]
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
    with_std = n_runs > 1

    avg_time = fmt_duration(
        s["duration_sum"] / s["duration_n"] if s["duration_n"] else None
    )
    avg_cost = fmt_cost(s["cost_sum"] / s["cost_n"] if s["cost_n"] else None)
    avg_in = fmt_tokens(s["in_tok_sum"] / s["in_tok_n"] if s["in_tok_n"] else None)
    avg_out = fmt_tokens(s["out_tok_sum"] / s["out_tok_n"] if s["out_tok_n"] else None)
    avg_rsn = fmt_tokens(s["rsn_tok_sum"] / s["rsn_tok_n"] if s["rsn_tok_n"] else None)

    prec_str = fmt_metric(prec_m, prec_s, with_std)
    rec_str = fmt_metric(rec_m, rec_s, with_std)
    acc_str = fmt_metric(acc_m, acc_s, with_std)

    print(
        f"  {m:<{mw}} {n_runs:>5} {s['tp']:>4} {s['fp']:>4} {s['tn']:>4} {s['fn']:>4} "
        f"{prec_str:>15} {rec_str:>15} {acc_str:>15} "
        f"{avg_time:>8} {avg_cost:>9} {avg_in:>9} {avg_out:>9} {avg_rsn:>9}"
    )
