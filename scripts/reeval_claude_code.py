"""Re-evaluate existing equivaproof run artifacts using the current _evaluate logic.

Usage:
    python scripts/reeval_equivaproof.py runs/<timestamp>

Updates each pairs/<id>/equivaproof/result.json in place (preserving streaming
metrics) and rewrites results.jsonl with corrected is_equivalent values.
"""

import argparse
import json
import sys
from pathlib import Path

# Allow importing from src/ without installing.
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.verify.equivaproof.equivaproof import EquivaProofVerifier


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dir", type=Path, help="Timestamped run directory")
    args = parser.parse_args()

    run_dir: Path = args.run_dir
    pairs_dir = run_dir / "pairs"
    results_jsonl = run_dir / "results.jsonl"

    if not pairs_dir.exists():
        sys.exit(f"pairs/ not found in {run_dir}")

    repo_root = Path(__file__).parent.parent
    checker = EquivaProofVerifier(runs_dir=run_dir, repo_root=repo_root)

    updated: dict[str, bool] = {}

    pair_dirs = sorted(p for p in pairs_dir.iterdir() if p.is_dir())
    for pair_dir in pair_dirs:
        cc_dir = pair_dir / "equivaproof"
        wd = cc_dir / "wd"
        if not wd.exists():
            continue

        pair_id = pair_dir.name
        result_path = cc_dir / "result.json"
        old_result = json.loads(result_path.read_text())

        print(f"  {pair_id} ...", end=" ", flush=True)
        new_meta = checker._evaluate(wd)

        # Preserve streaming metrics from the original agent run.
        streaming_keys = ("duration_s", "stop_reason", "input_tokens", "output_tokens", "cost_usd")
        for k in streaming_keys:
            if k in old_result:
                new_meta[k] = old_result[k]

        result_path.write_text(json.dumps(new_meta, indent=2))

        old_equiv = old_result.get("is_equivalent")
        new_equiv = new_meta["is_equivalent"]
        updated[pair_id] = new_equiv

        changed = old_equiv != new_equiv
        tag = "CHANGED" if changed else "same"
        print(f"{tag}  {old_equiv} -> {new_equiv}  [{new_meta['agent_decision']}]")

    # Patch results.jsonl.
    if not results_jsonl.exists():
        print("\nNo results.jsonl found — skipping.")
        return

    rows = [json.loads(l) for l in results_jsonl.read_text().splitlines() if l.strip()]
    for row in rows:
        if row["method"] == "equivaproof" and row["pair_id"] in updated:
            row["is_equivalent"] = updated[row["pair_id"]]

    results_jsonl.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    print(f"\nPatched results.jsonl ({len(rows)} rows, {len(updated)} equivaproof entries).")


if __name__ == "__main__":
    main()
