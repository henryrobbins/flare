#!/usr/bin/env python3
"""Verify EvoCut formulation structure: each non-a formulation equals a plus one extra constraint."""

import argparse
import json
import sys
from pathlib import Path
from typing import cast

EVOCUT_PROBLEM_NUMS = set(range(6, 13))
COMPARED_KEYS = ("valid", "parameters", "assumptions", "variables", "objective")


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text())  # type: ignore[no-any-return]


def diff_summary(a_val: object, b_val: object, key: str) -> list[str]:
    if a_val == b_val:
        return []
    return [f"  {key} differs"]


def check_formulation(
    problem_id: str,
    formulation_id: str,
    base: dict[str, object],
    other: dict[str, object],
    verbose: bool,
) -> bool:
    """Return True if other == base + exactly one extra explicit constraint."""
    mismatches: list[str] = []

    for key in COMPARED_KEYS:
        mismatches += diff_summary(base.get(key), other.get(key), key)

    base_constraints = cast(list[dict[str, object]], base.get("constraints", []))
    other_constraints = cast(list[dict[str, object]], other.get("constraints", []))

    n_base = len(base_constraints)
    n_other = len(other_constraints)

    if n_other != n_base + 1:
        mismatches.append(
            f"  constraints: expected {n_base + 1} (a's {n_base} + 1), got {n_other}"
        )
    else:
        for i, (bc, oc) in enumerate(zip(base_constraints, other_constraints)):
            if bc != oc:
                mismatches.append(
                    f"  constraints[{i}] differs from a's constraint[{i}]"
                )

    label = f"{problem_id}.{formulation_id}"
    if mismatches:
        print(f"FAIL  {label}")
        if verbose:
            for m in mismatches:
                print(m)
        return False

    if verbose and n_other == n_base + 1:
        extra = other_constraints[-1]
        print(f"OK    {label}  +  {extra.get('description', '(no description)')}")
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
        help="show extra constraint description on pass, mismatch details on fail",
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
