import math
import os
import pickle
import random
import logging
from typing import Dict, List, Tuple


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s — %(levelname)s — %(message)s",
)


def generate_random_tsp_instances(
    num_instances: int,
    n_range: Tuple[int, int] = (20, 250),
    dims: int = 2,
    bbox: Tuple[float, float] = (0.0, 1.0),
    seed: int | None = None,
) -> List[Dict]:
    """
    Build `num_instances` random Euclidean TSP problems.

    Parameters
    ----------
    num_instances : int
        How many separate problems to generate.
    n_range : (int, int)
        Inclusive minimum and maximum number of nodes.
    dims : int
        Coordinate dimensionality (2 for 2-D, 3 for 3-D, …).
    bbox : (float, float)
        Lower/upper bound for each coordinate axis.
    seed : int | None
        RNG seed for reproducibility.

    Returns
    -------
    List[Dict]
        Problems in the same dict format used by your original code.
    """
    if seed is not None:
        random.seed(seed)

    lo, hi = bbox
    all_problems: List[Dict] = []

    for idx in range(num_instances):
        n_nodes = random.randint(*n_range)

        # Random coordinates for every node (1-indexed)
        coords: Dict[int, List[float]] = {
            node_id: [random.uniform(lo, hi) for _ in range(dims)]
            for node_id in range(1, n_nodes + 1)
        }

        # Symmetric distance matrix C
        C: Dict[Tuple[int, int], float] = {}
        node_ids = list(coords.keys())

        for i in range(n_nodes):
            for j in range(i + 1, n_nodes):
                u, v = node_ids[i], node_ids[j]
                d = math.dist(coords[u], coords[v])
                C[(u, v)] = C[(v, u)] = d  # store both directions

        all_problems.append(
            {
                "name": f"rand_{idx}_{n_nodes}",
                "NODES": node_ids,
                "TOURS": None,
                "coords": coords,
                "args": {"n": n_nodes, "c": C},
            }
        )

        logging.debug(f"Generated problem rand_{idx}_{n_nodes} with {n_nodes} nodes")

    return all_problems


def save_to_pickle(data: List[Dict], output_path: str) -> None:
    """Persist `data` to `output_path` in pickle format."""
    try:
        logging.info(f"Saving {len(data)} items to {output_path} …")
        with open(output_path, "wb") as fh:
            pickle.dump(data, fh)
    except IOError as exc:
        logging.error(f"Failed to save {output_path}: {exc}")
        raise


def main() -> None:
    NUM_INSTANCES = 500  # total problems to create
    N_RANGE = (20, 250)  # min / max nodes
    BBOX = (0.0, 1.0)  # coordinate bounds
    SEED = 14  # RNG seed
    VALIDATION_SPLIT = 0.9
    PICKLE_PATH = "data/tsp.pkl"

    # Ensure target directory exists
    os.makedirs(os.path.dirname(PICKLE_PATH), exist_ok=True)

    # Step 1  Generate fresh random instances
    logging.info("Generating random TSP instances …")
    problems = generate_random_tsp_instances(
        num_instances=NUM_INSTANCES,
        n_range=N_RANGE,
        bbox=BBOX,
        seed=SEED,
    )

    # Step 2  Sort small → large (optional but mirrors original script)
    problems.sort(key=lambda p: len(p["NODES"]))

    logging.info(f"Total generated problems: {len(problems)}")

    # Step 3  Shuffle before splitting
    random.seed(SEED)
    random.shuffle(problems)

    # Step 4  Split train / validation
    total = len(problems)
    val_count = int(total * VALIDATION_SPLIT)
    train_count = total - val_count

    train_split = problems[:train_count]
    val_split = problems[train_count:]

    logging.info(f"Training problems:   {len(train_split)}")
    logging.info(f"Validation problems: {len(val_split)}")

    # Step 5  Save pickles
    save_to_pickle(train_split, PICKLE_PATH)

    base_name = os.path.splitext(os.path.basename(PICKLE_PATH))[0]
    val_path = os.path.join(os.path.dirname(PICKLE_PATH), base_name + "_val.pkl")
    save_to_pickle(val_split, val_path)

    logging.info("Done ✔")


if __name__ == "__main__":
    main()
