"""
Download Beasley CAP benchmark instances and write data.json

Source: https://commalab.di.unipi.it/files/Data/mexch/BeasleyData.zip
Data is extracted to data_source/ (gitignored) and parsed into data.json.

Currently writes a single instance (cap103). To switch to all instances,
change INSTANCE_FILTER to None and set MULTI_INSTANCE = True.
"""

import json
import urllib.request
import zipfile
from pathlib import Path
from typing import List


SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
ZIP_URL = "https://commalab.di.unipi.it/files/Data/mexch/BeasleyData.zip"
ZIP_PATH = DATA_SOURCE_DIR / "BeasleyData.zip"
INSTANCES_DIR = DATA_SOURCE_DIR / "Istanze"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

# Set to None to include all instances; set MULTI_INSTANCE = True to write a list.
INSTANCE_FILTER = "cap103"
MULTI_INSTANCE = False


def download_and_extract() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not ZIP_PATH.exists():
        urllib.request.urlretrieve(ZIP_URL, ZIP_PATH)

    if not INSTANCES_DIR.exists():
        with zipfile.ZipFile(ZIP_PATH) as zf:
            zf.extractall(DATA_SOURCE_DIR)


def parse_cap_file(fp: Path) -> dict:
    with fp.open("r") as fh:
        m, n = map(int, fh.readline().split())

        caps, fixed = [], []
        for _ in range(m):
            cap, cost = map(float, fh.readline().split())
            caps.append(cap)
            fixed.append(cost)

        first_data = fh.readline().split()
        if len(first_data) != n:
            raise ValueError(
                f"{fp}: expected {n} demands on one line, got {len(first_data)}"
            )

        demands = list(map(float, first_data))
        cost_rows: List[List[float]] = [
            list(map(float, fh.readline().split())) for _ in range(m)
        ]
        if any(len(r) != n for r in cost_rows):
            raise ValueError(f"{fp}: malformed cost rows")

    # c[i][j] = cost from warehouse j to customer i  (shape n×m, 0-indexed)
    c = [[cost_rows[j][i] for j in range(m)] for i in range(n)]

    return {
        "n": n,
        "m": m,
        "d": demands,
        "u": caps,
        "f": fixed,
        "c": c,
    }


def main() -> None:
    download_and_extract()

    pattern = INSTANCE_FILTER if INSTANCE_FILTER else "cap*"
    files = sorted(INSTANCES_DIR.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No files matching '{pattern}' in {INSTANCES_DIR}")

    instances = []
    for fp in files:
        inst = parse_cap_file(fp)
        instances.append(inst)

    if MULTI_INSTANCE:
        instances.sort(key=lambda d: (d["n"], d["m"]))
        OUTPUT_PATH.write_text(json.dumps(instances, indent=2))
    else:
        OUTPUT_PATH.write_text(json.dumps(instances[0], indent=2))


if __name__ == "__main__":
    main()
