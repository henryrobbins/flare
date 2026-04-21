import os, pickle, random, logging
from typing import List, Tuple, Dict
import numpy as np
from typing import List, Dict, Tuple
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format="%(asctime)s — %(levelname)s — %(message)s")


def save_to_pickle(obj, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        pickle.dump(obj, f, protocol=pickle.HIGHEST_PROTOCOL)
    logging.info("Saved %s", path)


def permute_rows(x: np.ndarray) -> np.ndarray:
    """Permute columns of each row independently."""
    ix_i = np.tile(np.arange(x.shape[0]), (x.shape[1], 1)).T
    ix_j = np.random.sample(x.shape).argsort(axis=1)
    return x[ix_i, ix_j]


def uni_instance_gen(n_j: int, n_m: int, low: int, high: int):
    """Generate a uniform random JSSP instance."""
    times = np.random.randint(low, high + 1, size=(n_j, n_m))
    machines = np.expand_dims(np.arange(1, n_m + 1), axis=0).repeat(n_j, axis=0)
    machines = permute_rows(machines)
    return times, machines


def generate_random_jssp_instances(
    num_instances: int = 20,
    size_range: List[Tuple[int, int]] = [
        # (12,12),
        (15, 15),
        (15, 10),
        (15, 5),
        (16, 11),
        (14, 10),
        (14, 11),
        (15, 11),
        (14, 14),
        (20, 5),
        (20, 10),
        (20, 20),
        (20, 15),
    ],
    ptime_range: Tuple[int, int] = (5, 20),
    random_seed: int = 14,
) -> List[Dict]:

    np.random.seed(random_seed)
    random.seed(random_seed)
    insts: List[Dict] = []

    for idx in tqdm(range(num_instances), desc="Generating JSSP"):
        n_jobs, n_machs = random.choice(size_range)
        t, m = uni_instance_gen(n_jobs, n_machs, *ptime_range)

        insts.append(
            {
                "name": f"jssp_{idx}_{n_jobs}x{n_machs}",
                "args": {
                    "n_jobs": n_jobs,
                    "n_machines": n_machs,
                    "times": t.tolist(),
                    "machines": m.tolist(),
                },
            }
        )
    return insts


if __name__ == "__main__":
    OUT = "data/jssp.pkl"
    OUT_VAL = "data/jssp_val.pkl"
    NUM_INSTANCES = 100
    val_split = 0.1
    random.seed(14)

    instances = generate_random_jssp_instances(num_instances=NUM_INSTANCES)
    instances.sort(key=lambda d: (d["args"]["n_jobs"], d["args"]["n_machines"]))

    logging.info(
        "Generated %d instances (up to %d×%d).",
        len(instances),
        instances[-1]["args"]["n_jobs"],
        instances[-1]["args"]["n_machines"],
    )

    v = int(len(instances) * val_split)

    # Shuffle the instances
    random.shuffle(instances)

    # Split the instances into training and validation sets
    save_to_pickle(instances[v:], OUT)
    save_to_pickle(instances[:v], OUT_VAL)
    logging.info("Saved %d instances for training and %d for validation.", len(instances) - v, v)
