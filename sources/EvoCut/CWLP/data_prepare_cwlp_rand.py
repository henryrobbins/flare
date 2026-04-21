import random
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

Number = float


def generate_cwlp_instance(
    *,
    n_customers: int = 1_000,
    n_warehouses: int = 100,
    demand_range: Tuple[int, int] = (50, 1_500),
    capacity_buffer: float = 1.3,
    capacity_spread: float = 0.1,
    fixed_cost_range: Tuple[int, int] = (7_000, 15_000),
    unit_cost_range: Tuple[float, float] = (5.0, 75.0),
    seed: int = None,
) -> Tuple[
    List[int],
    List[int],
    Dict[int, int],
    Dict[int, int],
    Dict[int, Number],
    Dict[Tuple[int, int], Number],
]:
    """Return **(I, J, d, u, f, c)** suitable for ``create_model``."""

    rng = random.Random(seed)

    # Customers & demands (heterogeneous)
    I: List[int] = list(range(1, n_customers + 1))
    d: Dict[int, int] = {i: rng.randint(*demand_range) for i in I}
    total_demand = sum(d.values())

    # Warehouses & capacities (quasi‑constant)
    J: List[int] = list(range(1, n_warehouses + 1))
    avg_capacity = int((total_demand * capacity_buffer) / n_warehouses)
    u: Dict[int, int] = {
        j: int(avg_capacity * rng.uniform(1 - capacity_spread, 1 + capacity_spread)) for j in J
    }

    # Fixed opening costs
    f: Dict[int, Number] = {j: rng.randint(*fixed_cost_range) for j in J}

    # Assignment costs (total cost per customer‑warehouse pair)
    coeff_low, coeff_high = unit_cost_range
    c: Dict[Tuple[int, int], Number] = {}
    for i in I:
        for j in J:
            unit_cost = rng.uniform(coeff_low, coeff_high)
            c[(i, j)] = unit_cost * d[i]

    return I, J, d, u, f, c


# OR‑Lib‑STYLE WRITER (optional)


def write_orlib_file(
    path: str,
    I: Iterable[int],
    J: Iterable[int],
    d: Dict[int, int],
    u: Dict[int, int],
    f: Dict[int, Number],
    c: Dict[Tuple[int, int], Number],
    *,
    float_format: str = "{:.5f}",
) -> None:
    """Dump the instance in the exact text format of OR‑Lib *cap##* files."""

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    with path.open("w", encoding="ascii") as fh:
        fh.write(f"{len(J)} {len(I)}\n")
        for j in J:
            fh.write(f"{u[j]} {float_format.format(f[j])}\n")
        for i in I:
            costs = " ".join(float_format.format(c[(i, j)]) for j in J)
            fh.write(f"{d[i]} {costs}\n")


# BATCH GENERATOR + PICKLER (template‑style)

import logging
import os
import pickle
from typing import List

import numpy as np
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


# helper: save‑to‑pickle


def save_to_pickle(data: List[Dict], output_path: str) -> None:
    """Pickle *data* list to *output_path* with max protocol."""
    try:
        logging.info(f"Saving {len(data)} instance(s) → '{output_path}' …")
        with open(output_path, "wb") as fh:
            pickle.dump(data, fh, protocol=pickle.HIGHEST_PROTOCOL)
        logging.info("Done.")
    except IOError as err:
        logging.error(f"Could not save to '{output_path}': {err}")
        raise


# single‑instance wrapper


def _build_one_instance(
    *,
    n_customers: int,
    n_sites: int,
    capacity_buffer: float,
    demand_range: Tuple[int, int],
    fixed_cost_range: Tuple[int, int],
    unit_cost_range: Tuple[float, float],
    rng: np.random.Generator,
) -> Dict:
    """Wrap ``generate_cwlp_instance`` with metadata for batch generation."""

    I, J, d, u, f, c = generate_cwlp_instance(
        n_customers=n_customers,
        n_warehouses=n_sites,
        demand_range=demand_range,
        capacity_buffer=capacity_buffer,
        fixed_cost_range=fixed_cost_range,
        unit_cost_range=unit_cost_range,
        seed=int(rng.integers(0, 2**32 - 1)),
    )

    total_demand = sum(d.values())
    total_capacity = sum(u.values())

    return {
        "args": {"I": I, "J": J, "d": d, "u": u, "f": f, "c": c},
        "meta": {
            "n_customers": n_customers,
            "n_sites": n_sites,
            "total_demand": total_demand,
            "total_capacity": total_capacity,
            "capacity_factor": total_capacity / total_demand,
        },
    }


# batch generator (template‑like)


def generate_random_cwlp_problems(
    *,
    num_problems: int = 10,
    customer_range: Tuple[int, int] = (1_000, 2_000),
    site_range: Tuple[int, int] = (100, 400),
    demand_range: Tuple[int, int] = (50, 1_500),
    capacity_buffer_range: Tuple[float, float] = (1.1, 1.4),
    fixed_cost_range: Tuple[int, int] = (7_000, 15_000),
    unit_cost_range: Tuple[float, float] = (5.0, 75.0),
    base_seed: int = 42,
) -> List[Dict]:
    """Create *num_problems* diverse CWLP instances and return as list."""

    problems: List[Dict] = []
    for k in tqdm(range(num_problems), desc="Generating CWLP problems"):
        rng = np.random.default_rng(base_seed + k)

        n_customers = int(rng.integers(*customer_range))
        n_sites = int(rng.integers(*site_range))
        cap_buffer = float(rng.uniform(*capacity_buffer_range))

        inst = _build_one_instance(
            n_customers=n_customers,
            n_sites=n_sites,
            capacity_buffer=cap_buffer,
            demand_range=demand_range,
            fixed_cost_range=fixed_cost_range,
            unit_cost_range=unit_cost_range,
            rng=rng,
        )
        inst["name"] = f"cwlp_{n_customers}x{n_sites}_cap{cap_buffer:.2f}"
        problems.append(inst)

    return problems


def main() -> None:
    OUTPUT_PATH = "data/cwlp_val.pkl"
    NUM_PROBLEMS = 100
    VALID_SPLIT = 0.20  # 20 % hold‑out for validation

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    logging.info("Starting CWLP batch generation …")

    cwlp_problems = generate_random_cwlp_problems(
        num_problems=NUM_PROBLEMS,
        customer_range=(1_000, 2_000),  # customise as needed
        site_range=(100, 400),
        demand_range=(50, 1_500),
        capacity_buffer_range=(1.1, 1.3),
        base_seed=42,
    )

    # Sort for convenience (ascending |I|)
    cwlp_problems.sort(key=lambda d: d["meta"]["n_customers"])
    logging.info(f"Total instances generated: {len(cwlp_problems)}")

    # Train / validation split
    val_count = int(len(cwlp_problems) * VALID_SPLIT)
    train_problems = cwlp_problems[:-val_count] if val_count else cwlp_problems
    val_problems = cwlp_problems[-val_count:] if val_count else []

    logging.info(f"Training instances   : {len(train_problems)}")
    logging.info(f"Validation instances : {len(val_problems)}")

    # Save pickles
    save_to_pickle(train_problems, OUTPUT_PATH)
    if val_problems:
        base_name = os.path.splitext(os.path.basename(OUTPUT_PATH))[0]
        valid_path = os.path.join(os.path.dirname(OUTPUT_PATH), base_name + "_val.pkl")
        save_to_pickle(val_problems, valid_path)


if __name__ == "__main__":
    main()
