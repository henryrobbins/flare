#!/usr/bin/env python3
"""Regenerate solve.py for every formulation, then gen_params + solve and check objs."""

import argparse
import json
import math
import subprocess
import sys

from formulation_bench import Dataset
from tqdm import tqdm

OBJECTIVE_REL_TOL = 1e-6


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
        help="comma-separated problem numbers to validate (e.g. 1,2,3; default: all)",
    )
    args = parser.parse_args()

    dataset = Dataset(args.dataset)

    if args.problems is not None:
        problem_nums = {int(x.strip()) for x in args.problems.split(",")}
    else:
        problem_nums = None

    formulations = [
        (pid, problem, fid, f)
        for pid, problem in dataset.problems.items()
        if problem_nums is None or pid in problem_nums
        for fid, f in problem.formulations.items()
    ]

    failures: list[tuple[int, str, str]] = []

    for pid, problem, fid, formulation in tqdm(
        formulations, desc="validating", unit="formulation"
    ):
        label = f"problem {pid} / formulation {fid}"

        (formulation.path / "solve.py").write_text(formulation.gurobipy_code)

        try:
            formulation.gen_params()
        except subprocess.CalledProcessError:
            tqdm.write(f"FAIL  gen_params  {label}")
            failures.append((pid, fid, "gen_params"))
            continue

        try:
            subprocess.run(
                [
                    "python",
                    str(formulation.path / "solve.py"),
                    str(formulation.path / "parameters.json"),
                    str(formulation.path / "solution.json"),
                ],
                check=True,
            )
        except subprocess.CalledProcessError:
            tqdm.write(f"FAIL  solve       {label}")
            failures.append((pid, fid, "solve"))
            continue

        if not formulation.valid:
            continue

        expected = problem.solution
        if expected is None:
            continue

        solution_file = formulation.path / "solution.json"
        actual_objective = json.loads(solution_file.read_text())["objective"]
        if not math.isclose(
            actual_objective, expected.objective, rel_tol=OBJECTIVE_REL_TOL
        ):
            tqdm.write(
                f"FAIL  solution    {label}"
                f"  (got {actual_objective}, expected {expected.objective})"
            )
            failures.append((pid, fid, "solution"))

    n_formulations = len(formulations)
    print(f"\n{n_formulations - len(failures)}/{n_formulations} formulations passed")

    if failures:
        print("\nfailures:")
        for pid, fid, stage in failures:
            print(f"  problem {pid} / formulation {fid}  [{stage}]")
        sys.exit(1)


if __name__ == "__main__":
    main()
