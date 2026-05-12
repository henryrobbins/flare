"""
Generate data.json for the Blood Bank Netherlands problem (p14).

Generates a synthetic instance of the DC-hospital allocation problem.
Hospitals are placed at random 2-D coordinates (simulating the Netherlands),
candidate DC locations are drawn as a random subset of the hospitals, and
travel times are Euclidean distances scaled and rounded to integer minutes.

Output keys match problem.json:
  nS       -- number of candidate DC locations
  nH       -- number of hospital locations
  n        -- number of DCs to open
  T_limit  -- maximum allowed travel time (minutes)
  T        -- 2-D list (nS × nH) of integer travel times
"""

import json
import random
from itertools import combinations
from pathlib import Path

import numpy as np

SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR / "data.json"

SEED = 42
NUM_HOSPITALS = 20  # nH
NUM_CANDIDATES = 6  # nS
NUM_DCS = 3  # n
TRAVEL_TIME_LIMIT = 60  # T_limit (minutes)


def generate_data(
    seed: int = SEED,
    num_hospitals: int = NUM_HOSPITALS,
    num_candidates: int = NUM_CANDIDATES,
    num_dcs: int = NUM_DCS,
    travel_time_limit: float = TRAVEL_TIME_LIMIT,
) -> dict:
    np.random.seed(seed)
    random.seed(seed)

    # Random 2-D coordinates for all hospitals in a 100x100 unit grid
    coords = np.random.uniform(0, 100, size=(num_hospitals, 2))

    # Candidate DC locations are a random subset of hospital indices
    dc_indices = sorted(random.sample(range(num_hospitals), num_candidates))

    # Travel times: scaled Euclidean distance plus a small random offset
    T = []
    for i in dc_indices:
        row = []
        for j in range(num_hospitals):
            dist = float(np.linalg.norm(coords[i] - coords[j]))
            travel_time = int(round(dist * 1.2 + np.random.uniform(5, 15)))
            row.append(travel_time)
        T.append(row)

    return {
        "nS": num_candidates,
        "nH": num_hospitals,
        "n": num_dcs,
        "T_limit": travel_time_limit,
        "T": T,
    }


def is_feasible(data: dict) -> bool:
    T = data["T"]
    T_limit = data["T_limit"]
    nS, nH, n = data["nS"], data["nH"], data["n"]
    coverage = [set(j for j in range(nH) if T[i][j] <= T_limit) for i in range(nS)]
    return any(
        set().union(*(coverage[i] for i in combo)) == set(range(nH))
        for combo in combinations(range(nS), n)
    )


def main() -> None:
    seed = SEED
    while True:
        data = generate_data(seed=seed)
        if is_feasible(data):
            break
        seed += 1
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
