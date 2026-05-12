"""
Generate data.json for the Timor-Leste Hospital Location problem (p18).

Produces a small reproducible instance (~10 households, 3 existing hospitals,
5 candidate sites) adapted from the source data generator in
dataset/sources/Ferchtandiker2025/timor_leste/data_generator.py.

The output keys match exactly what formulations a and b gen_params.py consume:
  households, existing_hospitals, candidate_hospitals, all_hospitals,
  population, distance_indicators, max_new_hospitals.
"""

import json
import math
import random
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent / "data.json"

# Instance size parameters
N = 10  # Number of households
M_EX = 3  # Number of existing hospitals
NUM_NEW = 5  # Number of candidate hospital sites
S = 40.0  # Max allowed travel distance (km, generous for small grid)
P = 3  # Max new hospitals to open


def _rand_coords(rng: random.Random, n: int) -> list[tuple[float, float]]:
    """Return n random (x, y) points uniformly in [0, 100]^2."""
    return [(rng.uniform(0, 100), rng.uniform(0, 100)) for _ in range(n)]


def _euclidean(p: tuple[float, float], q: tuple[float, float]) -> float:
    return math.sqrt((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2)


def generate_data(seed: int = 42) -> dict:
    """Generate a small Timor-Leste hospital location instance."""
    rng = random.Random(seed)

    # Sets (string IDs)
    households = [f"H{i + 1}" for i in range(N)]
    existing_hospitals = [f"EJ{i + 1}" for i in range(M_EX)]
    candidate_hospitals = [f"CJ{i + 1}" for i in range(NUM_NEW)]
    all_hospitals = existing_hospitals + candidate_hospitals

    # Random coordinates on a 100x100 grid
    household_coords = _rand_coords(rng, N)
    hospital_coords = _rand_coords(rng, M_EX + NUM_NEW)

    # Population per household
    population = {h: rng.randint(50, 499) for h in households}

    # Travel distances (Euclidean with small noise, rounded)
    travel_distances: dict[str, dict[str, float]] = {}
    for i, h in enumerate(households):
        travel_distances[h] = {}
        for j, hosp in enumerate(all_hospitals):
            dist = _euclidean(household_coords[i], hospital_coords[j])
            travel_distances[h][hosp] = round(dist + rng.uniform(-5, 5), 2)

    # Distance indicators: 1 if within S, else 0
    distance_indicators: dict[str, dict[str, int]] = {}
    for h in households:
        distance_indicators[h] = {}
        for hosp in all_hospitals:
            distance_indicators[h][hosp] = int(travel_distances[h][hosp] <= S)

    return {
        "households": households,
        "existing_hospitals": existing_hospitals,
        "candidate_hospitals": candidate_hospitals,
        "all_hospitals": all_hospitals,
        "population": population,
        "travel_distances": travel_distances,
        "distance_indicators": distance_indicators,
        "max_travel_distance": S,
        "max_new_hospitals": P,
    }


def main() -> None:
    data = generate_data(seed=42)
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))
    print(f"Data written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
