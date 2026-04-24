"""
Generate data.json for the Air Traffic Flow Management problem (p13).

Generates a synthetic instance with a fleet of flights, a set of locations
(airports/sectors), and a discrete time horizon. Transition times between
locations are drawn as small random integers; rewards and capacities are
drawn uniformly at random.

Output keys match problem.json:
  nP   -- number of flights
  nA   -- number of locations (airports/sectors)
  nT   -- number of time periods
  tau  -- 2-D list (nA × nA) of integer transition times between locations
  r    -- 2-D list (nA × nT) of rewards for being at location a at time t
  cap  -- 2-D list (nA × nT) of integer capacity of location a at time t
"""

import json
import random
import numpy as np
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR / "data.json"

SEED = 42
NUM_FLIGHTS = 5       # nP
NUM_LOCATIONS = 6     # nA
NUM_TIME_PERIODS = 10 # nT


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

    # Transition times: 0 on diagonal, small positive integer for off-diagonal
    tau = [
        [
            0 if a == a2 else int(np.random.randint(1, 4))
            for a2 in range(nA)
        ]
        for a in range(nA)
    ]

    # Rewards: non-negative floats, rounded to 1 decimal place
    r = [
        [round(float(np.random.uniform(0.0, 10.0)), 1) for t in range(nT)]
        for a in range(nA)
    ]

    # Capacities: small positive integers
    cap = [
        [int(np.random.randint(1, nP + 1)) for t in range(nT)]
        for a in range(nA)
    ]

    return {
        "nP": nP,
        "nA": nA,
        "nT": nT,
        "tau": tau,
        "r": r,
        "cap": cap,
    }


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
