#!/usr/bin/env python3
"""Verify EvoCut formulation structure: each non-a formulation is a superset of a.

Checks that every non-base formulation contains all of a's parameters, assumptions,
variables, and constraints (as a prefix), and may additionally introduce new variables,
definitions, or constraints.
"""

import argparse
import json
import sys
from pathlib import Path
from typing import cast

EVOCUT_PROBLEM_NUMS = set(range(6, 13))
EXACT_KEYS = ("parameters", "assumptions", "objective")


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text())  # type: ignore[no-any-return]


def check_formulation(
    problem_id: str,
    formulation_id: str,
    base: dict[str, object],
    other: dict[str, object],
    verbose: bool,
) -> bool:
    """Return True if other is a superset of base (base's content is preserved in other)."""
    mismatches: list[str] = []

    # Parameters, assumptions, and objective must be identical.
    for key in EXACT_KEYS:
        if base.get(key) != other.get(key):
            mismatches.append(f"  {key} differs")

    # Variables: all of a's variables must be present and unchanged in other.
    base_vars = cast(dict[str, object], base.get("variables", {}))
    other_vars = cast(dict[str, object], other.get("variables", {}))
    for vname, vval in base_vars.items():
        if vname not in other_vars:
            mismatches.append(f"  variables[{vname!r}] missing")
        elif other_vars[vname] != vval:
            mismatches.append(f"  variables[{vname!r}] differs")

    # Constraints: a's constraints must appear as a prefix of other's constraints.
    base_constraints = cast(list[dict[str, object]], base.get("constraints", []))
    other_constraints = cast(list[dict[str, object]], other.get("constraints", []))
    n_base = len(base_constraints)
    n_other = len(other_constraints)

    if n_other < n_base:
        mismatches.append(
            f"  constraints: other has {n_other}, fewer than a's {n_base}"
        )
    elif n_other == n_base:
        mismatches.append("  constraints: no extra constraints beyond a's")
    else:
        for i, (bc, oc) in enumerate(zip(base_constraints, other_constraints)):
            if bc != oc:
                mismatches.append(f"  constraints[{i}] differs from a's constraint[{i}]")

    label = f"{problem_id}.{formulation_id}"
    if mismatches:
        print(f"FAIL  {label}")
        if verbose:
            for m in mismatches:
                print(m)
        return False

    extra_vars = [k for k in other_vars if k not in base_vars]
    extra_constraints = other_constraints[n_base:]
    extra_descs = [c.get("description", "(no description)") for c in extra_constraints]
    if verbose:
        extras = []
        if extra_vars:
            extras.append(f"vars={extra_vars}")
        if extra_descs:
            extras.append(f"constraints={extra_descs}")
        print(f"OK    {label}  +  {'; '.join(extras)}")
    else:
        print(f"OK    {label}")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "dataset",
        nargs="?",
        default="dataset",
        help="path to the dataset root (default: ./dataset)",
    )
    parser.add_argument(
        "--problems",
        "-p",
        help="comma-separated problem numbers to check (e.g. 6,7,8; default: all EvoCut problems 6-12)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="show extra variables/constraints on pass, mismatch details on fail",
    )
    args = parser.parse_args()

    if args.problems is not None:
        problem_nums = {int(x.strip()) for x in args.problems.split(",")}
    else:
        problem_nums = EVOCUT_PROBLEM_NUMS

    dataset_root = Path(args.dataset)
    failures: list[str] = []

    for num in sorted(problem_nums):
        pid = f"p{num}"
        problem_dir = dataset_root / "problems" / pid
        if not problem_dir.is_dir():
            print(f"SKIP  {pid}  (directory not found)", file=sys.stderr)
            continue

        base_path = problem_dir / "formulations" / "a" / "formulation.json"
        if not base_path.exists():
            print(f"SKIP  {pid}  (formulation a not found)", file=sys.stderr)
            continue

        base = load_json(base_path)

        formulations_dir = problem_dir / "formulations"
        fids = sorted(
            d.name for d in formulations_dir.iterdir() if d.is_dir() and d.name != "a"
        )

        for fid in fids:
            fpath = formulations_dir / fid / "formulation.json"
            if not fpath.exists():
                print(
                    f"SKIP  {pid}.{fid}  (formulation.json not found)", file=sys.stderr
                )
                continue
            other = load_json(fpath)
            ok = check_formulation(pid, fid, base, other, args.verbose)
            if not ok:
                failures.append(f"{pid}.{fid}")

    total = sum(
        len(
            [
                d
                for d in (dataset_root / "problems" / f"p{num}" / "formulations").iterdir()
                if d.is_dir() and d.name != "a"
            ]
        )
        for num in sorted(problem_nums)
        if (dataset_root / "problems" / f"p{num}" / "formulations").is_dir()
    )
    passed = total - len(failures)
    print(f"\n{passed}/{total} formulations passed")

    if failures:
        print("\nfailures:")
        for f in failures:
            print(f"  {f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
