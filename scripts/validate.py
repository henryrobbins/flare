#!/usr/bin/env python3
"""Run gen_params + solve for every formulation in the dataset."""

import argparse
import subprocess
import sys
from pathlib import Path

from tqdm import tqdm

from milp_eq_tools import Dataset


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "dataset",
        nargs="?",
        default="dataset",
        help="path to the dataset root (default: ./dataset)",
    )
    args = parser.parse_args()

    dataset = Dataset(args.dataset)

    formulations = [
        (pid, fid, f)
        for pid, problem in dataset.problems.items()
        for fid, f in problem.formulations.items()
    ]

    failures: list[tuple[int, str, str]] = []

    for pid, fid, formulation in tqdm(formulations, desc="validating", unit="formulation"):
        label = f"problem {pid} / formulation {fid}"
        try:
            formulation.gen_params()
        except subprocess.CalledProcessError:
            tqdm.write(f"FAIL  gen_params  {label}")
            failures.append((pid, fid, "gen_params"))
            continue

        try:
            formulation.solve()
        except subprocess.CalledProcessError:
            tqdm.write(f"FAIL  solve       {label}")
            failures.append((pid, fid, "solve"))

    print(f"\n{len(formulations) - len(failures)}/{len(formulations)} formulations passed")

    if failures:
        print("\nfailures:")
        for pid, fid, stage in failures:
            print(f"  problem {pid} / formulation {fid}  [{stage}]")
        sys.exit(1)


if __name__ == "__main__":
    main()
