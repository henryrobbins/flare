"""
Generate data.json for the Dutch Housing Problem (p15).

Adapted from dataset/sources/Ferchtandiker2025/dutch_housing_problem/data_generator.py.
Uses a small instance (10 floors) with a fixed seed (42) for reproducibility.

The generated data includes floor configurations, apartment layouts, profit
coefficients, and housing-policy constraints used by both formulation a and b.
"""

import json
import random
from pathlib import Path

import numpy as np

OUTPUT_PATH = Path(__file__).parent / "data.json"

TOTAL_FLOORS = 5
SEED = 42


def generate_data(seed: int = SEED, total_floors: int = TOTAL_FLOORS) -> dict:
    random.seed(seed)
    np.random.seed(seed)

    # Sets
    sectors = ["social", "middle", "free"]  # I
    areas = [36, 42, 48, 52, 58, 60, 71]  # J
    # NOTE: We're using a smaller instance than considered in the original paper
    # areas = [36, 42, 48, 52, 58, 60, 68, 70, 71, 96, 131]  # J
    owners = ["corporation", "investor", "private"]  # H

    # Floor parts and their apartment areas
    floor_parts = {
        "a": [36, 36, 42, 42, 48, 48],
        "b": [42, 42, 52, 52, 58],
        "c": [60, 60, 71, 71],
        # NOTE: We're using a smaller instance than considered in the original paper
        # "d": [70, 96, 96],
        # "e": [131, 131],
    }

    # Generate all possible floor configurations (V) as all 2-part combinations
    # (with replacement), e.g. "aa", "ab", ..., "ee"
    part_keys = list(floor_parts.keys())
    floor_configurations = []
    for i in range(len(part_keys)):
        for j in range(i, len(part_keys)):
            floor_configurations.append(part_keys[i] + part_keys[j])

    # For each floor configuration, enumerate apartments (A_v) and their areas
    apartments_in_config = {}
    apartment_area = {}
    # apartments_by_area_config[str(area)][config]: count of apts with that area in config
    apartments_by_area_config = {}

    for v in floor_configurations:
        part1, part2 = v[0], v[1]
        apt_areas = floor_parts[part1] + floor_parts[part2]
        apartments = [f"apt{a + 1}" for a in range(len(apt_areas))]
        apartments_in_config[v] = apartments
        apartment_area[v] = {a: area for a, area in zip(apartments, apt_areas)}
        # Build R_{jv}: count of apartments of each area in this configuration
        for area in areas:
            area_key = str(area)
            if area_key not in apartments_by_area_config:
                apartments_by_area_config[area_key] = {}
            apartments_by_area_config[area_key][v] = apt_areas.count(area)

    # Number of apartments in each configuration
    apartments_per_config = {
        v: len(apartments_in_config[v]) for v in floor_configurations
    }

    floors = list(range(1, total_floors + 1))

    # Profit per apartment (p_{ijh}), keyed by sector -> str(area) -> owner
    profit_per_apartment = {}
    for i in sectors:
        profit_per_apartment[i] = {}
        for j in areas:
            area_key = str(j)
            profit_per_apartment[i][area_key] = {}
            for h in owners:
                # Social sector: lower profit; free sector: higher profit
                base = 10000 if i == "social" else (20000 if i == "middle" else 30000)
                area_factor = (j - min(areas)) / (max(areas) - min(areas))
                owner_factor = (
                    1.0 if h == "investor" else (0.9 if h == "private" else 0.8)
                )
                profit_per_apartment[i][area_key][h] = int(
                    base * (1 + 0.5 * area_factor) * owner_factor
                    + random.randint(-1000, 1000)
                )

    # Minimal area per sector/owner (m_{ih})
    min_area_requirement = {}
    for i in sectors:
        min_area_requirement[i] = {}
        for h in owners:
            if i == "social" and h == "corporation":
                min_area_requirement[i][h] = 40
            elif i == "middle" and h == "corporation":
                min_area_requirement[i][h] = 50
            elif i == "free":
                min_area_requirement[i][h] = 60
            else:
                min_area_requirement[i][h] = 36  # fallback to smallest area

    # Minimum percentage of apartments in each sector (b_i)
    min_sector_percentage = {"social": 0.4, "middle": 0.4, "free": 0.0}

    # Minimum average area per sector (s_i)
    min_avg_area_per_sector = {"social": 40, "middle": 50, "free": 60}

    # Minimum ownership percentage (o_h)
    min_ownership_percentage = {"corporation": 0.0, "investor": 0.7, "private": 0.0}

    data = {
        "sectors": sectors,
        "areas": areas,
        "owners": owners,
        "floor_configurations": floor_configurations,
        "apartments_in_config": apartments_in_config,
        "apartment_area": apartment_area,
        "apartments_per_config": apartments_per_config,
        "apartments_by_area_config": apartments_by_area_config,
        "floors": floors,
        "total_floors": total_floors,
        "profit_per_apartment": profit_per_apartment,
        "min_area_requirement": min_area_requirement,
        "min_sector_percentage": min_sector_percentage,
        "min_avg_area_per_sector": min_avg_area_per_sector,
        "min_ownership_percentage": min_ownership_percentage,
    }

    return data


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2))
    print(f"Data written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
