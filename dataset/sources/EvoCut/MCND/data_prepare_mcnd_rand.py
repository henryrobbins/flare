import os
import pickle
import random
import itertools
import logging
from typing import Dict, List, Tuple

import networkx as nx
from tqdm import tqdm


# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


def save_to_pickle(data: List[Dict], output_path: str) -> None:
    """Save data to a pickle file."""
    try:
        logging.info(f"Saving data to {output_path}...")
        with open(output_path, "wb") as file:
            pickle.dump(data, file)
        logging.info("Data successfully saved.")
    except IOError as e:
        logging.error(f"Failed to save data: {e}")
        raise


def _connectivity_and_capacity_ok(
    nodes: List[int],
    arcs: List[Tuple[int, int]],
    capacities: Dict[Tuple[int, int], int],
    demand: Dict[int, int],
    origin: Dict[int, int],
    destination: Dict[int, int],
) -> bool:
    """
    Conservative feasibility check:
      1. a directed s–t path exists for every commodity,
      2. arc-capacity min-cut ≥ demand for each commodity.
    """
    G = nx.DiGraph()
    G.add_nodes_from(nodes)
    for i, j in arcs:
        G.add_edge(i, j, capacity=capacities[(i, j)])

    for k in demand:
        s, t = origin[k], destination[k]
        if not nx.has_path(G, s, t):
            return False
        if nx.maximum_flow_value(G, s, t, capacity="capacity") < demand[k]:
            return False
    return True


def save_to_pickle(obj, path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        pickle.dump(obj, f, protocol=pickle.HIGHEST_PROTOCOL)
    logging.info("Saved %s", path)


def generate_random_mcnd_problems(
    num_problems: int = 5,
    node_range: Tuple[int, int] = (5, 10),
    commodity_range: Tuple[int, int] = (2, 5),
    arc_density: float = 0.4,
    capacity_range: Tuple[int, int] = (20, 100),
    fixed_cost_range: Tuple[int, int] = (50, 200),
    variable_cost_range: Tuple[int, int] = (10, 50),
    demand_range: Tuple[int, int] = (5, 30),
    random_seed: int = 42,
) -> List[Dict]:
    """
    Generate random MCND (Multi-Commodity Network Design) problem instances.

    Parameters:
    -----------
    num_problems : int
        Number of problem instances to generate.
    node_range : (int, int)
        Range (inclusive) for number of nodes: (min_nodes, max_nodes).
    commodity_range : (int, int)
        Range (inclusive) for number of commodities: (min_commodities, max_commodities).
    arc_density : float
        Fraction of possible arcs to include (0 < arc_density <= 1).
    capacity_range : (int, int)
        Range for arc capacities.
    fixed_cost_range : (int, int)
        Range for fixed costs on arcs.
    variable_cost_range : (int, int)
        Range for variable (per-unit) transport costs on arcs.
    demand_range : (int, int)
        Range for commodity demands.
    random_seed : int
        Random seed for reproducibility.

    Returns:
    --------
    List[Dict]
        A list of randomly generated MCND problem instances. Each element is a dict
        with the following structure:
            {
                "name": str,
                "N": List[int],         # list of node IDs
                "A": List[Tuple[int]],
                "K": List[int],         # commodity IDs
                "c": Dict[(i,j), cost],
                "f": Dict[(i,j), fixed_cost],
                "u": Dict[(i,j), capacity],
                "d": Dict[k, demand],
                "O": Dict[k, origin_node],
                "D": Dict[k, dest_node],
            }
    """
    random.seed(random_seed)

    problems = []
    attempts = 0

    for problem_idx in tqdm(range(num_problems), desc="Generating MCND problems"):
        while True:  # regenerate until feasibility passes
            attempts += 1

            n = random.randint(*node_range)
            k = random.randint(*commodity_range)

            nodes = list(range(1, n + 1))
            commodities = list(range(1, k + 1))

            # sparse directed arcs
            arcs = [
                (i, j)
                for i, j in itertools.permutations(nodes, 2)
                if random.random() <= arc_density
            ]

            # arc attributes
            capacity = {(i, j): random.randint(*capacity_range) for (i, j) in arcs}
            fixed_cost = {(i, j): random.randint(*fixed_cost_range) for (i, j) in arcs}
            variable_cost = {(i, j): random.randint(*variable_cost_range) for (i, j) in arcs}

            # commodity data
            origin = {}
            destination = {}
            demand = {}
            for commodity_id in commodities:
                o = random.choice(nodes)
                d = random.choice(nodes)
                while d == o:
                    d = random.choice(nodes)
                origin[commodity_id] = o
                destination[commodity_id] = d
                demand[commodity_id] = random.randint(*demand_range)

            if _connectivity_and_capacity_ok(nodes, arcs, capacity, demand, origin, destination):
                break  # feasible instance found – exit while-True

        # assemble problem dictionary
        problems.append(
            {
                "name": f"random_mcnd_{problem_idx}",
                "args": {
                    "N": nodes,
                    "A": arcs,
                    "K": commodities,
                    "c": variable_cost,
                    "f": fixed_cost,
                    "u": capacity,
                    "d": demand,
                    "O": origin,
                    "D": destination,
                },
            }
        )

    return problems


def main():

    OUTPUT_PATH = "data/mcnd.pkl"
    NUM_PROBLEMS_TO_GENERATE = 20
    random.seed(14)

    logging.info("Generating hard-but-feasible MCND instances …")
    mcnd_problems = generate_random_mcnd_problems(num_problems=NUM_PROBLEMS_TO_GENERATE)

    # Optional: sort them by the number of nodes, or any other criterion you like
    mcnd_problems.sort(key=lambda x: len(x["args"]["N"]))

    logging.info(f"Number of MCND problems generated: {len(mcnd_problems)}")

    # train/validation split
    val_split = 0.2  # 20% of the problems will be used for validation
    output_train = OUTPUT_PATH
    output_val = OUTPUT_PATH.replace(".pkl", "_val.pkl")

    v = int(len(mcnd_problems) * val_split)
    save_to_pickle(mcnd_problems[:-v], output_train)
    save_to_pickle(mcnd_problems[-v:], output_val)

    logging.info(
        "Done. Train = %d  |  Validation = %d",
        len(mcnd_problems) - v,
        v,
    )


if __name__ == "__main__":
    main()
