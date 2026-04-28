#!/usr/bin/env python3
"""Extract Lean files from a run's pairs into results/<run_id>/<problem>/<a_b>/.

For each pair in the run, copies:
  equivaproof/wd/A/Formulation.lean  -> results/<run_id>/<problem>/<a_b>/A/Formulation.lean
  equivaproof/wd/B/Formulation.lean  -> results/<run_id>/<problem>/<a_b>/B/Formulation.lean
  equivaproof/wd/Equivalence.lean    -> results/<run_id>/<problem>/<a_b>/Equivalence.lean

Pair directory names are expected to follow the pattern p<N>_<a>__p<N>_<b>.

Usage:
    python scripts/extract_lean_results.py <run_id>
    python scripts/extract_lean_results.py --last      # most recent run
"""

import argparse
import re
import shutil
import sys
from pathlib import Path


PAIR_RE = re.compile(r"^p(\d+)_(\w+)__p\d+_(\w+)$")


def rewrite_equivalence_imports(path: Path, run_id: str, problem: str, form_pair: str) -> None:
    # run_id starts with a digit so it needs Lean's «...» quoting
    base = f"results.«{run_id}».{problem}.{form_pair}"
    text = path.read_text()
    text = text.replace("import A.Formulation", f"import {base}.A.Formulation")
    text = text.replace("import B.Formulation", f"import {base}.B.Formulation")
    path.write_text(text)


def pair_to_output_path(pair_id: str) -> tuple[str, str] | None:
    m = PAIR_RE.match(pair_id)
    if not m:
        return None
    problem, form_a, form_b = m.group(1), m.group(2), m.group(3)
    return f"p{problem}", f"{form_a}_{form_b}"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("run_id", nargs="?", metavar="RUN_ID", help="Run ID to extract")
    group.add_argument("--last", action="store_true", help="Use the most recent run")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    runs_dir = repo_root / "runs"
    results_dir = repo_root / "results"

    if args.last:
        candidates = sorted(p for p in runs_dir.iterdir() if p.is_dir())
        if not candidates:
            print("error: no runs found", file=sys.stderr)
            sys.exit(1)
        run_id = candidates[-1].name
    else:
        run_id = args.run_id

    run_dir = runs_dir / run_id
    if not run_dir.is_dir():
        print(f"error: run not found: {run_dir}", file=sys.stderr)
        sys.exit(1)

    pairs_dir = run_dir / "pairs"
    if not pairs_dir.is_dir():
        print(f"error: no pairs directory in run: {run_dir}", file=sys.stderr)
        sys.exit(1)

    copied = 0
    skipped = 0

    for pair_path in sorted(pairs_dir.iterdir()):
        if not pair_path.is_dir():
            continue

        pair_id = pair_path.name
        parsed = pair_to_output_path(pair_id)
        if parsed is None:
            print(f"  warning: unrecognised pair name '{pair_id}', skipping", file=sys.stderr)
            skipped += 1
            continue

        problem, form_pair = parsed
        wd = pair_path / "equivaproof" / "wd"

        out_dir = results_dir / run_id / problem / form_pair
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "A").mkdir(exist_ok=True)
        (out_dir / "B").mkdir(exist_ok=True)

        files = [
            (wd / "A" / "Formulation.lean", out_dir / "A" / "Formulation.lean"),
            (wd / "B" / "Formulation.lean", out_dir / "B" / "Formulation.lean"),
            (wd / "Equivalence.lean", out_dir / "Equivalence.lean"),
        ]

        pair_ok = True
        for src, dst in files:
            if not src.exists():
                print(f"  warning: missing {src.relative_to(repo_root)}", file=sys.stderr)
                pair_ok = False
            else:
                shutil.copy2(src, dst)

        if pair_ok:
            rewrite_equivalence_imports(out_dir / "Equivalence.lean", run_id, problem, form_pair)
            copied += 1
        else:
            skipped += 1

    print(f"Run {run_id}: {copied} pairs extracted, {skipped} skipped")
    print(f"Output: {results_dir / run_id}")


if __name__ == "__main__":
    main()
