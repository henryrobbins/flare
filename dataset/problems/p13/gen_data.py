"""
Generate data.json for the Air Traffic Flow Management problem (p13).

Generates a synthetic instance with a fleet of flights, a set of locations
(airports/sectors), and a discrete time horizon. Adjacency between locations
is drawn at random (with self-adjacency forced to 1); rewards and capacities
are drawn uniformly at random.

Output keys match problem.json:
  nP   -- number of flights
  nA   -- number of locations (airports/sectors)
  nT   -- number of time periods
  adj  -- 2-D list (nA x nA) of binary adjacency entries
  r    -- 2-D list (nA x nT) of rewards for being at location a at time t
  cap  -- 2-D list (nA x nT) of integer capacity of location a at time t
"""

import json
import random
from pathlib import Path

import numpy as np

SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR / "data.json"

SEED = 42
NUM_FLIGHTS = 5  # nP
NUM_LOCATIONS = 6  # nA
NUM_TIME_PERIODS = 10  # nT


def generate_data(
    seed: int = SEED,
    num_flights: int = NUM_FLIGHTS,
    num_locations: int = NUM_LOCATIONS,
    num_time_periods: int = NUM_TIME_PERIODS,
) -> dict:
    np.random.seed(seed)
    random.seed(seed)

    nP = num_flights
    nA = num_locations
    nT = num_time_periods

    # Adjacency: 1 on diagonal (self-adjacency), random 0/1 off-diagonal
    adj = [
        [1 if a == a2 else int(np.random.randint(0, 2)) for a2 in range(nA)]
        for a in range(nA)
    ]

    # Rewards: non-negative floats, rounded to 1 decimal place
    r = [
        [round(float(np.random.uniform(0.0, 10.0)), 1) for t in range(nT)]
        for a in range(nA)
    ]

    # Capacities: small positive integers
    cap = [[int(np.random.randint(1, nP + 1)) for t in range(nT)] for a in range(nA)]

    return {
        "nP": nP,
        "nA": nA,
        "nT": nT,
        "adj": adj,
        "r": r,
        "cap": cap,
    }


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
