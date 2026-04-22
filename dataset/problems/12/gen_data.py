"""
Download TSPLIB95 instances and write data.json (TSP).

Source: http://comopt.ifi.uni-heidelberg.de/software/TSPLIB95/tsp/ALL_tsp.tar.gz
Data is extracted to data_source/ (gitignored). The ulysses16 instance is used.

Parameters written match problem.json: n, c
where c is the n×n travel-cost matrix (0-indexed, row-major list of lists).
"""

import gzip
import json
import tarfile
import urllib.request
from pathlib import Path

import tsplib95

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
TAR_URL = "https://comopt.ifi.uni-heidelberg.de/software/TSPLIB95/tsp/ALL_tsp.tar.gz"
TAR_PATH = DATA_SOURCE_DIR / "ALL_tsp.tar.gz"
EXTRACT_DIR = DATA_SOURCE_DIR / "tsp"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

INSTANCE_NAME = "ulysses16.tsp"


def download_and_extract() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not TAR_PATH.exists():
        urllib.request.urlretrieve(TAR_URL, TAR_PATH)

    if not EXTRACT_DIR.exists():
        EXTRACT_DIR.mkdir(exist_ok=True)
        with tarfile.open(TAR_PATH, "r:gz") as tar:
            tar.extractall(EXTRACT_DIR)


def load_tsp_instance(gz_path: Path) -> dict | None:
    """Decompress a .tsp.gz file and parse it with tsplib95."""
    tsp_path = gz_path.with_suffix("")  # strip .gz
    try:
        with gzip.open(gz_path, "rt") as f:
            content = f.read()
        tsp_path.write_text(content)
        problem = tsplib95.load(str(tsp_path))
    except Exception:
        return None
    finally:
        if tsp_path.exists():
            tsp_path.unlink()

    nodes = list(problem.get_nodes())
    n = len(nodes)
    node_to_idx = {node: i for i, node in enumerate(nodes)}

    c = [[0] * n for _ in range(n)]
    for i_node in nodes:
        for j_node in nodes:
            if i_node != j_node:
                w = problem.get_weight(i_node, j_node)
                c[node_to_idx[i_node]][node_to_idx[j_node]] = w

    return {"n": n, "c": c}


def main() -> None:
    download_and_extract()

    gz_path = EXTRACT_DIR / (INSTANCE_NAME + ".gz")
    if not gz_path.exists():
        raise FileNotFoundError(f"{gz_path} not found in {EXTRACT_DIR}")

    inst = load_tsp_instance(gz_path)
    if inst is None:
        raise ValueError(f"Failed to load instance {INSTANCE_NAME}")

    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


if __name__ == "__main__":
    main()
