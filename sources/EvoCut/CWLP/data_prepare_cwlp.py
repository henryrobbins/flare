import os
import pickle
import logging
from typing import Dict, List, Tuple
from pathlib import Path

import numpy as np
from tqdm import tqdm

#  logging setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


#  helper: save-to-pickle
def save_to_pickle(data: List[Dict], output_path: str) -> None:
    """Save a list of dictionaries to *output_path* using pickle."""
    try:
        logging.info(f"Saving {len(data)} instance(s) to '{output_path}' …")
        with open(output_path, "wb") as fh:
            pickle.dump(data, fh, protocol=pickle.HIGHEST_PROTOCOL)
        logging.info("Done.")
    except IOError as err:
        logging.error(f"Could not save to '{output_path}': {err}")
        raise


#  single-file parser
from pathlib import Path
from typing import Dict, List, Tuple


def parse_cap_file(fp: Path) -> Dict:
    """
    Parse either CAP-A or CAP-B format and return:
        { "name", "args": {I,J,d,u,f,c}, "meta": {...} }
    """
    with fp.open("r") as fh:
        m, n = map(int, fh.readline().split())
        # capacities & fixed costs
        caps, fixed = [], []
        for _ in range(m):
            cap, cost = map(float, fh.readline().split())
            caps.append(cap)
            fixed.append(cost)

        # sniff the next line
        first_data = fh.readline().split()

        if len(first_data) == n:  #  CAP-B  (demands present)
            demands = list(map(float, first_data))  # n numbers
            # cost matrix is m rows × n cols  ->  read & transpose
            cost_rows: List[List[float]] = [
                list(map(float, fh.readline().split())) for _ in range(m)
            ]
            if any(len(r) != n for r in cost_rows):
                raise ValueError(f"{fp}: malformed cost rows")
            costs = [[cost_rows[j][i] for j in range(m)] for i in range(n)]  # transpose -> n×m

    # build Pyomo-ready dictionaries
    I = list(range(1, n + 1))
    J = list(range(1, m + 1))
    d = {i: demands[i - 1] for i in I}
    u = {j: caps[j - 1] for j in J}
    f = {j: fixed[j - 1] for j in J}
    c = {(i, j): costs[i - 1][j - 1] for i in I for j in J}

    return {
        "name": fp.stem,
        "args": {"I": I, "J": J, "d": d, "u": u, "f": f, "c": c},
        "meta": {
            "n_customers": n,
            "n_sites": m,
            "total_demand": float(sum(demands)),
            "total_capacity": float(sum(caps)),
        },
    }


#  batch extractor
def load_cap_directory(
    directory: str,
    pattern: str = "cap*",
) -> List[Dict]:
    """
    Scan *directory* for files matching *pattern* (default 'cap*'),
    parse each CAP instance, and return a list of dicts.
    """
    dirpath = Path(directory)
    files = sorted(dirpath.glob(pattern))
    if not files:
        logging.warning(f"No files found in '{directory}' matching '{pattern}'.")
        return []

    instances: List[Dict] = []
    for fp in tqdm(files, desc="Parsing CAP instances"):
        try:
            inst = parse_cap_file(fp)
            instances.append(inst)
        except Exception as err:
            logging.error(f"Failed to parse '{fp}': {err}")

    return instances


#  main script
def main() -> None:
    INPUT_DIR = "data/cwlp/"  # Note you need to download the data from  https://commalab.di.unipi.it/datasets/mex/
    OUTPUT_PATH = "data/cwlp_val.pkl"

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    logging.info(f"Scanning CAP directory '{INPUT_DIR}' …")

    cap_instances = load_cap_directory(INPUT_DIR, pattern="cap*")
    logging.info(f"Total instances parsed: {len(cap_instances)}")

    # (optional) sort by problem size
    cap_instances.sort(key=lambda d: (d["meta"]["n_customers"], d["meta"]["n_sites"]))

    # save
    save_to_pickle(cap_instances, OUTPUT_PATH)


if __name__ == "__main__":
    main()
