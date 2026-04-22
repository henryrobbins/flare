"""
Download MMCF R dataset and write data.json (MCND).

Source: https://commalab.di.unipi.it/files/Data/MMCF/R.tgz
Data is extracted to data_source/ (gitignored) and a single small instance
is selected at random (seed=42) and written to data.json.

Parameters written match problem.json: n, m, K, tail, head, c, f, u, O, D, d
where arcs and commodities are 0-indexed.
"""

import json
import random
import tarfile
import urllib.request
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
TGZ_URL = "https://commalab.di.unipi.it/files/Data/MMCF/R.tgz"
TGZ_PATH = DATA_SOURCE_DIR / "R.tgz"
EXTRACT_DIR = DATA_SOURCE_DIR  # archive extracts .dow files directly (no R/ subdirectory)
OUTPUT_PATH = SCRIPT_DIR / "data.json"

RANDOM_SEED = 42
MAX_NODES = 20  # keep only small instances


def download_and_extract() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not TGZ_PATH.exists():
        urllib.request.urlretrieve(TGZ_URL, TGZ_PATH)

    if not any(DATA_SOURCE_DIR.glob("*.dow")):
        with tarfile.open(TGZ_PATH, "r:gz") as tar:
            tar.extractall(DATA_SOURCE_DIR)


def parse_dow_file(fp: Path) -> dict | None:
    lines = fp.read_text().splitlines()

    header = lines[1].split()
    num_nodes = int(header[0])
    num_arcs = int(header[1])
    num_commodities = int(header[2])

    tail, head, c_cost, u_cap, f_fixed = [], [], [], [], []
    for line in lines[2 : num_arcs + 2]:
        data = line.split()
        i, j = int(data[0]) - 1, int(data[1]) - 1  # convert to 0-indexed
        tail.append(i)
        head.append(j)
        c_cost.append(int(data[2]))
        u_cap.append(int(data[3]))
        f_fixed.append(int(data[4]))

    O_origin, D_dest, d_demand = [], [], []
    for line in lines[num_arcs + 2 :]:
        data = line.split()
        O_origin.append(int(data[0]) - 1)  # 0-indexed
        D_dest.append(int(data[1]) - 1)
        d_demand.append(int(data[2]))

    if len(tail) != num_arcs or len(O_origin) != num_commodities:
        return None

    return {
        "n": num_nodes,
        "m": num_arcs,
        "K": num_commodities,
        "tail": tail,
        "head": head,
        "c": c_cost,
        "f": f_fixed,
        "u": u_cap,
        "O": O_origin,
        "D": D_dest,
        "d": d_demand,
    }


def main() -> None:
    download_and_extract()

    dow_files = sorted(EXTRACT_DIR.rglob("*.dow"))
    if not dow_files:
        raise FileNotFoundError(f"No .dow files found under {EXTRACT_DIR}")

    instances = []
    for fp in dow_files:
        inst = parse_dow_file(fp)
        if inst is not None and inst["n"] <= MAX_NODES:
            instances.append((fp.name, inst))

    if not instances:
        raise ValueError(f"No instances with n <= {MAX_NODES} found.")

    random.seed(RANDOM_SEED)
    name, inst = random.choice(instances)

    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


if __name__ == "__main__":
    main()
