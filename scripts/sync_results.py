#!/usr/bin/env python3
"""Sync a results.jsonl to reflect current dataset/pairs.json.

Rows for pairs no longer in pairs.json are dropped. The ground_truth field
is updated to match the current pairs.json value.
"""

import argparse
import json
import sys

parser = argparse.ArgumentParser(description="Sync results.jsonl against current dataset/pairs.json.")
parser.add_argument("-r", "--run-id", required=True, help="Run ID (e.g. 20260425T213917Z)")
args = parser.parse_args()

pairs_path = "dataset/pairs.json"
results_path = f"runs/{args.run_id}/results.jsonl"

with open(pairs_path) as f:
    pairs = json.load(f)

current = {}
for p in pairs:
    key = (f"p{p['a']['problem']}", p["a"]["formulation"], f"p{p['b']['problem']}", p["b"]["formulation"])
    current[key] = p["reformulation"]

rows = []
skipped = 0
updated = 0
with open(results_path) as f:
    for line in f:
        r = json.loads(line)
        key = (r["problem_a"], r["formulation_a"], r["problem_b"], r["formulation_b"])
        if key not in current:
            skipped += 1
            rows.append(r)
            continue
        gt = current[key]
        if r.get("ground_truth") != gt:
            r["ground_truth"] = gt
            updated += 1
        rows.append(r)

with open(results_path, "w") as f:
    for r in rows:
        f.write(json.dumps(r) + "\n")

print(f"Kept {len(rows)} rows ({skipped} not in current pairs.json, left unchanged), updated ground_truth on {updated}.", file=sys.stderr)
