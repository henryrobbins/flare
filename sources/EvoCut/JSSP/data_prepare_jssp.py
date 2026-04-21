import os, pickle, random, logging, re
from pathlib import Path
from typing import List, Dict, Tuple
import numpy as np
from tqdm import tqdm

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


def save_to_pickle(obj, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        pickle.dump(obj, f, protocol=pickle.HIGHEST_PROTOCOL)
    logging.info("Saved %s", path)


def parse_taillard_file(path: Path) -> Tuple[np.ndarray, np.ndarray]:
    """
    Read a Taillard file (with or without extension) and
    return (times, machines) 0 based numpy arrays.
    """
    with open(path) as f:
        n_jobs, n_machs = map(int, re.findall(r"\S+", f.readline()))
        times = np.zeros((n_jobs, n_machs), dtype=int)
        machines = np.zeros((n_jobs, n_machs), dtype=int)

        for j in range(n_jobs):
            tokens = list(map(int, re.findall(r"\S+", f.readline())))
            for k in range(n_machs):
                machines[j, k] = tokens[2 * k]  # already 0‑based
                times[j, k] = tokens[2 * k + 1]
    return times, machines


def load_jssp_directory(root_dir: str) -> List[Dict]:
    """
    Recursively load *all* non hidden regular files in root_dir
    and convert them into the standard JSSP dict schema.
    """
    insts: List[Dict] = []
    root = Path(root_dir)

    candidates = [p for p in root.rglob("*") if p.is_file() and not p.name.startswith(".")]

    for fp in tqdm(sorted(candidates), desc="Parsing instances"):
        try:
            times, machines = parse_taillard_file(fp)
        except Exception as e:
            logging.warning("Skipping %s (%s)", fp, e)
            continue

        n_jobs, n_machs = times.shape
        insts.append(
            {
                "name": fp.relative_to(root).as_posix(),  # keeps subdir info
                "args": {
                    "n_jobs": n_jobs,
                    "n_machines": n_machs,
                    "times": times.tolist(),
                    "machines": machines.tolist(),
                },
            }
        )
    return insts


if __name__ == "__main__":
    ROOT_DIR = "data/taillard"  # directory with 'ta01', 'ta11_20', ... Download it from https://github.com/ai-for-decision-making-tue/Job_Shop_Scheduling_Benchmark_Environments_and_Instances/tree/main/data/jsp
    OUT_TRAIN = "data/jssp.pkl"
    OUT_VAL = "data/jssp_val.pkl"
    VAL_SPLIT = 0.5
    RNG_SEED = 14

    random.seed(RNG_SEED)

    instances = load_jssp_directory(ROOT_DIR)
    if not instances:
        raise RuntimeError(f"No valid instances found under {ROOT_DIR}")

    # sort → deterministic, then shuffle for split
    instances.sort(key=lambda d: (d["args"]["n_jobs"], d["args"]["n_machines"]))
    logging.info("Loaded %d instances.", len(instances))

    random.shuffle(instances)
    v = int(len(instances) * VAL_SPLIT)

    save_to_pickle(instances[v:], OUT_TRAIN)
    save_to_pickle(instances[:v], OUT_VAL)
    logging.info("Saved %d train and %d validation instances.", len(instances) - v, v)
