"""
Clone JSPLIB and write data.json (JSSP).

Source: git@github.com:tamy0612/JSPLIB.git  (instances/ta01 – ta80)
Instance format: first line is "n m", then n lines each with m pairs of
"machine_index processing_time" (0-indexed machines, Taillard convention).

Currently writes a single instance (ta01). To switch to all instances,
change INSTANCE_FILTER to None and set MULTI_INSTANCE = True.
"""

import json
import subprocess
from pathlib import Path
from typing import List

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
REPO_URL = "git@github.com:tamy0612/JSPLIB.git"
REPO_DIR = DATA_SOURCE_DIR / "JSPLIB"
INSTANCES_DIR = REPO_DIR / "instances"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

# Set to None to include all instances; set MULTI_INSTANCE = True to write a list.
INSTANCE_FILTER = "ta01"
MULTI_INSTANCE = False


def clone_or_update() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not REPO_DIR.exists():
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(REPO_DIR)],
            check=True,
        )


def parse_taillard_file(fp: Path) -> dict:
    lines = fp.read_text().splitlines()
    n, m = map(int, lines[0].split())

    p: List[List[int]] = []
    Om: List[List[int]] = []

    for i in range(1, n + 1):
        tokens = list(map(int, lines[i].split()))
        machines = tokens[0::2]
        times = tokens[1::2]
        Om.append(machines)
        p.append(times)

    return {"n": n, "m": m, "p": p, "Om": Om}


def main() -> None:
    clone_or_update()

    pattern = INSTANCE_FILTER if INSTANCE_FILTER else "ta*"
    files = sorted(INSTANCES_DIR.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No files matching '{pattern}' in {INSTANCES_DIR}")

    instances = []
    for fp in files:
        inst = parse_taillard_file(fp)
        instances.append(inst)

    if MULTI_INSTANCE:
        OUTPUT_PATH.write_text(json.dumps(instances, indent=2))
    else:
        OUTPUT_PATH.write_text(json.dumps(instances[0], indent=2))


if __name__ == "__main__":
    main()
