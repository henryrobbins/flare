"""Re-evaluate existing flare run artifacts using the current _evaluate logic.

Usage:
    python scripts/reeval_flare.py runs/<timestamp> [--pairs p1_a__p1_b ...]

Updates each pairs/<id>/flare/result.json in place (preserving streaming
metrics) and rewrites results.jsonl with corrected is_reformulation values.
Pairs missing from results.jsonl entirely are inserted.
"""

import argparse
import json
import sys
from pathlib import Path

# Allow importing from src/ without installing.
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.verify.flare.flare import FLAREVerifier


def _streaming_metrics_from_jsonl(cc_dir: Path) -> dict:
    """Extract streaming metrics from claude_output.jsonl when result.json is absent."""
    jsonl = cc_dir / "claude_output.jsonl"
    if not jsonl.exists():
        return {}
    for line in reversed(jsonl.read_text().splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") == "result":
            return {
                "duration_s": round(event.get("duration_ms", 0) / 1000, 1),
                "stop_reason": event.get("stop_reason"),
                "input_tokens": event.get("usage", {}).get("input_tokens"),
                "output_tokens": event.get("usage", {}).get("output_tokens"),
                "cost_usd": event.get("total_cost_usd"),
            }
    return {}


def _pair_id_to_parts(pair_id: str) -> tuple[str, str, str, str]:
    """p4_a__p4_e -> (p4, a, p4, e)"""
    a_part, b_part = pair_id.split("__")
    segs_a = a_part.rsplit("_", 1)
    segs_b = b_part.rsplit("_", 1)
    return segs_a[0], segs_a[1], segs_b[0], segs_b[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", type=Path, help="Timestamped run directory")
    parser.add_argument(
        "--pairs",
        nargs="+",
        metavar="PAIR_ID",
        help="Only re-evaluate these pair IDs (e.g. p4_a__p4_g)",
    )
    args = parser.parse_args()

    run_dir: Path = args.run_dir
    pairs_dir = run_dir / "pairs"
    results_jsonl = run_dir / "results.jsonl"

    if not pairs_dir.exists():
        sys.exit(f"pairs/ not found in {run_dir}")

    repo_root = Path(__file__).parent.parent

    # Read the model from the first available config.json (only needed to satisfy
    # the constructor; _evaluate doesn't use it).
    model = "claude-sonnet-4-6"
    for p in pairs_dir.iterdir():
        cfg = p / "flare" / "config.json"
        if cfg.exists():
            model = json.loads(cfg.read_text()).get("model", model)
            break

    checker = FLAREVerifier(repo_root=repo_root, model=model)

    updated: dict[str, bool] = {}
    new_rows: list[dict] = []

    pair_dirs = sorted(p for p in pairs_dir.iterdir() if p.is_dir())
    if args.pairs:
        pair_dirs = [p for p in pair_dirs if p.name in args.pairs]
        missing = set(args.pairs) - {p.name for p in pair_dirs}
        if missing:
            sys.exit(f"Pair(s) not found: {', '.join(sorted(missing))}")

    # Build set of pair_ids already in results.jsonl.
    existing_ids: set[str] = set()
    if results_jsonl.exists():
        for line in results_jsonl.read_text().splitlines():
            line = line.strip()
            if line:
                row = json.loads(line)
                if row.get("method") == "flare":
                    existing_ids.add(row["pair_id"])

    for pair_dir in pair_dirs:
        cc_dir = pair_dir / "flare"
        wd = cc_dir / "wd"
        if not wd.exists():
            continue

        pair_id = pair_dir.name
        result_path = cc_dir / "result.json"
        old_result = json.loads(result_path.read_text()) if result_path.exists() else {}

        print(f"  {pair_id} ...", end=" ", flush=True)
        new_meta = checker._evaluate(wd)

        # Preserve streaming metrics from result.json; fall back to claude_output.jsonl.
        streaming_keys = (
            "duration_s",
            "stop_reason",
            "input_tokens",
            "output_tokens",
            "cost_usd",
        )
        fallback = _streaming_metrics_from_jsonl(cc_dir) if not old_result else {}
        for k in streaming_keys:
            if k in old_result:
                new_meta[k] = old_result[k]
            elif k in fallback:
                new_meta[k] = fallback[k]

        result_path.write_text(json.dumps(new_meta, indent=2))

        old_equiv = old_result.get("is_reformulation")
        new_equiv = new_meta["is_reformulation"]
        updated[pair_id] = new_equiv

        changed = old_equiv != new_equiv
        tag = "CHANGED" if changed else "same"
        print(f"{tag}  {old_equiv} -> {new_equiv}  [{new_meta['agent_decision']}]")

        # Collect rows that need to be inserted (not already in results.jsonl).
        if pair_id not in existing_ids:
            problem_a, form_a, problem_b, form_b = _pair_id_to_parts(pair_id)
            equiv_file = (
                repo_root
                / "dataset"
                / "reformulations"
                / problem_a
                / f"{form_a}_{form_b}.lean"
            )
            ground_truth = equiv_file.exists()
            new_rows.append(
                {
                    "pair_id": pair_id,
                    "problem_a": problem_a,
                    "formulation_a": form_a,
                    "problem_b": problem_b,
                    "formulation_b": form_b,
                    "ground_truth": ground_truth,
                    "method": "flare",
                    "is_reformulation": new_equiv,
                    "duration_s": new_meta.get("duration_s"),
                    "cost_usd": new_meta.get("cost_usd"),
                    "artifacts_dir": str(
                        cc_dir.resolve().relative_to(repo_root.resolve())
                    ),
                    "error": None,
                }
            )

    # Patch results.jsonl.
    if not results_jsonl.exists():
        print("\nNo results.jsonl found — skipping.")
        return

    rows = [json.loads(l) for l in results_jsonl.read_text().splitlines() if l.strip()]
    for row in rows:
        if row["method"] == "flare" and row["pair_id"] in updated:
            row["is_reformulation"] = updated[row["pair_id"]]

    rows.extend(new_rows)
    results_jsonl.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    inserted = len(new_rows)
    print(
        f"\nPatched results.jsonl ({len(rows)} rows, {len(updated)} flare entries"
        + (f", {inserted} inserted" if inserted else "")
        + ")."
    )


if __name__ == "__main__":
    main()
