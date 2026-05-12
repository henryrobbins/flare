#!/usr/bin/env python3
"""Extract Lean files from a run's pairs into results/<run_id>/<problem>/<a_b>/<artifact>/.

For every artifact dir in the run (multiple FLARE harness/model variants
per pair are supported), copies:

  pairs/<pair>/<artifact>/wd/A/Formulation.lean      -> results/<run>/<problem>/<a_b>/<artifact>/A/Formulation.lean
  pairs/<pair>/<artifact>/wd/B/Formulation.lean      -> results/<run>/<problem>/<a_b>/<artifact>/B/Formulation.lean
  pairs/<pair>/<artifact>/wd/Reformulation.lean      -> results/<run>/<problem>/<a_b>/<artifact>/Reformulation.lean

Reformulation imports are rewritten to point at the new namespace.

Usage:
    python scripts/review/extract_flare_lean.py -r <run_id>
    python scripts/review/extract_flare_lean.py --last
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

PAIR_RE = re.compile(r"^p(\d+)_(\w+)__p\d+_(\w+)$")


_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_']*$")


def _quote(seg: str) -> str:
    """Quote a Lean namespace segment unless it's already a plain identifier."""
    return seg if _IDENT_RE.match(seg) else f"«{seg}»"


def rewrite_equivalence_imports(
    path: Path, run_id: str, problem: str, form_pair: str, artifact: str
) -> None:
    base = ".".join(
        ["results", _quote(run_id), problem, form_pair, _quote(artifact)]
    )
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


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-r", "--run-id", help="Run ID to extract")
    group.add_argument("--last", action="store_true", help="Use the most recent run")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    runs_dir = repo_root / "runs"
    results_dir = repo_root / "results"

    if args.last:
        candidates = sorted(p for p in runs_dir.iterdir() if p.is_dir())
        if not candidates:
            sys.exit("error: no runs found")
        run_id = candidates[-1].name
    else:
        run_id = args.run_id

    run_dir = runs_dir / run_id
    if not run_dir.is_dir():
        sys.exit(f"error: run not found: {run_dir}")
    pairs_dir = run_dir / "pairs"
    if not pairs_dir.is_dir():
        sys.exit(f"error: no pairs directory in run: {run_dir}")

    copied = 0
    skipped = 0

    for pair_path in sorted(pairs_dir.iterdir()):
        if not pair_path.is_dir():
            continue
        parsed = pair_to_output_path(pair_path.name)
        if parsed is None:
            print(
                f"  warning: unrecognised pair name '{pair_path.name}', skipping",
                file=sys.stderr,
            )
            skipped += 1
            continue
        problem, form_pair = parsed

        for artifact_path in sorted(pair_path.iterdir()):
            if not artifact_path.is_dir():
                continue
            wd = artifact_path / "wd"
            if not wd.is_dir():
                continue
            artifact = artifact_path.name

            out_dir = results_dir / run_id / problem / form_pair / artifact
            (out_dir / "A").mkdir(parents=True, exist_ok=True)
            (out_dir / "B").mkdir(parents=True, exist_ok=True)

            files = [
                (wd / "A" / "Formulation.lean", out_dir / "A" / "Formulation.lean"),
                (wd / "B" / "Formulation.lean", out_dir / "B" / "Formulation.lean"),
                (wd / "Reformulation.lean", out_dir / "Reformulation.lean"),
            ]

            artifact_ok = True
            for src, dst in files:
                if not src.exists():
                    print(
                        f"  warning: missing {src.relative_to(repo_root)}",
                        file=sys.stderr,
                    )
                    artifact_ok = False
                else:
                    shutil.copy2(src, dst)

            if artifact_ok:
                rewrite_equivalence_imports(
                    out_dir / "Reformulation.lean",
                    run_id,
                    problem,
                    form_pair,
                    artifact,
                )
                copied += 1
            else:
                skipped += 1

    print(f"Run {run_id}: {copied} artifact(s) extracted, {skipped} skipped")
    print(f"Output: {results_dir / run_id}")


if __name__ == "__main__":
    main()
