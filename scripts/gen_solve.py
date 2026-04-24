#!/usr/bin/env python3
"""Generate solve.py files from formulation.json."""

import argparse

from milp_eq_tools import Dataset


def parse_problem_ids(s: str | None) -> set[int] | None:
    if s is None:
        return None
    return {int(x.strip()) for x in s.split(",")}


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
        help="comma-separated list of problem numbers (e.g. 1,2,3)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print generated code without writing files",
    )
    args = parser.parse_args()

    dataset = Dataset(args.dataset)
    problem_filter = parse_problem_ids(args.problems)

    for pid, problem in dataset.problems.items():
        if problem_filter is not None and pid not in problem_filter:
            continue
        for fid, formulation in problem.formulations.items():
            code = formulation.gurobipy_code

            if args.dry_run:
                print(f"=== p{pid}/{fid}/solve.py ===")
                print(code)
            else:
                out = formulation.path / "solve.py"
                out.write_text(code)
                print(f"generated p{pid}/{fid}/solve.py")


if __name__ == "__main__":
    main()
