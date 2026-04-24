"""
Generate data.json for the UN Humanitarian Disaster Response Hub Location (UNHDR) problem.

Randomly generates a set of candidate hub locations, fixed hubs, disaster-prone
regions, affected populations, transportation costs, and travel times. The output
includes parameters for both formulation a (a_c / C_hc / t_hc) and formulation b
(a / C_alt / t), along with shared parameters T, n, M, and cardinality_C.

Tuple-keyed dicts (hub, region) are serialized with keys in Python repr format,
e.g. "('hub_1', 'region_1')", which is the format expected by gen_params.py.
"""

import json
import random
from pathlib import Path

import numpy as np

SEED = 42
OUTPUT_PATH = Path(__file__).parent / "data.json"


def main() -> None:
    random.seed(SEED)
    np.random.seed(SEED)

    # Set sizes
    num_hubs = random.randint(4, 7)
    num_fixed_hubs = random.randint(1, min(3, num_hubs - 1))
    num_regions = random.randint(5, 10)

    # Sets
    hubs = [f"hub_{i + 1}" for i in range(num_hubs)]
    fixed_hubs = sorted(random.sample(hubs, num_fixed_hubs))
    regions = [f"region_{j + 1}" for j in range(num_regions)]

    # Parameters
    # Number of people affected in each region
    a_c = {c: random.randint(1000, 10000) for c in regions}

    # Cost per person to transport from hub to region
    # Keys stored as Python repr of (hub, region) tuple so gen_params.py can read them
    C_hc = {
        f"('{h}', '{c}')": round(random.uniform(10, 100), 2)
        for h in hubs
        for c in regions
    }

    # Travel time (hours) from hub to region
    t_hc = {
        f"('{h}', '{c}')": random.randint(24, 96)
        for h in hubs
        for c in regions
    }

    # Maximum allowed travel time (hours)
    T = 72

    # Maximum number of hubs that can be opened (including fixed hubs)
    n = random.randint(num_fixed_hubs + 1, num_hubs)

    # Big-M constant
    M = 10000

    # Cardinality of C
    cardinality_C = num_regions

    # Alternate parameter names for formulation b (same values, different keys)
    a = {c: a_c[c] for c in regions}
    C_alt = dict(C_hc)
    t = dict(t_hc)

    data = {
        # Sets
        "H": hubs,
        "H_fixed": fixed_hubs,
        "C": regions,
        # Parameters for formulation a
        "a_c": a_c,
        "C_hc": C_hc,
        "t_hc": t_hc,
        "T": T,
        "n": n,
        "M": M,
        # Parameters for formulation b
        "a": a,
        "C_alt": C_alt,
        "t": t,
        "cardinality_C": cardinality_C,
    }

    OUTPUT_PATH.write_text(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
