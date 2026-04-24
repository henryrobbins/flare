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
import numpy as np
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR / "data.json"

SEED = 42
NUM_HOSPITALS = 20       # nH
NUM_CANDIDATES = 6       # nS
NUM_DCS = 3              # n
TRAVEL_TIME_LIMIT = 60   # T_limit (minutes)


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


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
