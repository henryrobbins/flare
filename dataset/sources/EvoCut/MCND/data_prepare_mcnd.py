import tarfile
import requests
import os
import pickle
import logging
import shutil
from tqdm import tqdm
from typing import Dict, List
import random

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


def download_file(url: str, output_path: str) -> None:
    """
    Download a file from a given URL and save it to the specified path.
    """
    try:
        logging.info(f"Downloading file from {url}...")
        response = requests.get(url)
        response.raise_for_status()  # Raise an exception for HTTP errors
        with open(output_path, "wb") as file:
            file.write(response.content)
        logging.info(f"File successfully downloaded and saved to {output_path}")
    except requests.exceptions.RequestException as e:
        logging.error(f"Failed to download file: {e}")
        raise


def extract_tar_gz(file_path: str, extract_path: str) -> None:
    """
    Extract a .tar.gz (or .tgz) file to the specified directory.
    """
    try:
        logging.info(f"Extracting {file_path} to {extract_path}...")
        with tarfile.open(file_path, "r:gz") as tar:
            tar.extractall(extract_path)
        logging.info("Extraction completed successfully.")
    except tarfile.TarError as e:
        logging.error(f"Failed to extract file: {e}")
        raise


def decompress_and_load_problems(extract_base_dir: str) -> Dict[str, Dict]:
    """
    Parse .dow files from the MCND datasets (C, CPlus, R).

    Returns a dictionary 'problems' where each key is a unique instance name
    (like 'C-c33.dow') and each value is a dict containing:
        {
            "N": set of nodes,
            "A": set of arcs,
            "K": set of commodities,
            "u": capacity dict,
            "f": fixed cost dict,
            "c": variable cost dict,
            "d": demand dict,
            "O": origin dict,
            "D": destination dict,
            "num_nodes": <int>,
            "num_arcs": <int>,
            "num_commodities": <int>,
        }
    """
    problems = {}

    # Loop over each dataset subdirectory (C, CPlus, R)
    for dataset_name in os.listdir(extract_base_dir):
        dataset_path = os.path.join(extract_base_dir, dataset_name)

        # Skip if not a directory
        if not os.path.isdir(dataset_path):
            continue

        # Loop over all .dow files in this dataset folder
        for filename in os.listdir(dataset_path):
            if filename.endswith(".dow"):
                file_path = os.path.join(dataset_path, filename)
                instance_name = f"{dataset_name}-{filename}"

                # Parse the .dow file
                with open(file_path, "r") as file:
                    lines = file.readlines()

                    # Header line is typically the second line (index=1)
                    header = lines[1].split()
                    num_nodes = int(header[0])
                    num_arcs = int(header[1])
                    num_commodities = int(header[2])

                    N = set()
                    A = set()
                    K = set()
                    u = {}
                    f_cost = {}
                    c_cost = {}
                    d_demand = {}
                    O_origin = {}
                    D_dest = {}

                    # Arc data lines
                    arc_data_lines = lines[2 : num_arcs + 2]
                    for line in arc_data_lines:
                        data = line.split()
                        i = int(data[0])
                        j = int(data[1])
                        c_ij = int(data[2])
                        u_ij = int(data[3])
                        f_ij = int(data[4])

                        N.update([i, j])
                        A.add((i, j))
                        u[(i, j)] = u_ij
                        f_cost[(i, j)] = f_ij
                        c_cost[(i, j)] = c_ij

                    # Commodity data lines
                    commodity_data_lines = lines[num_arcs + 2 :]
                    for idx, line in enumerate(commodity_data_lines):
                        data = line.split()
                        origin = int(data[0])
                        destination = int(data[1])
                        demand = int(data[2])
                        k = idx + 1  # 1-based commodity index

                        K.add(k)
                        O_origin[k] = origin
                        D_dest[k] = destination
                        d_demand[k] = demand

                    # Sanity checks against header counts
                    if len(N) != num_nodes:
                        logging.error(
                            f"[Sanity Check: {instance_name}] Mismatch in number of nodes: "
                            f"header={num_nodes}, extracted={len(N)}"
                        )
                        continue
                    if len(A) != num_arcs:
                        logging.error(
                            f"[Sanity Check: {instance_name}] Mismatch in number of arcs: "
                            f"header={num_arcs}, extracted={len(A)}"
                        )
                        continue
                    if len(K) != num_commodities:
                        logging.error(
                            f"[Sanity Check: {instance_name}] Mismatch in number of commodities: "
                            f"header={num_commodities}, extracted={len(K)}"
                        )
                        continue

                    problems[instance_name] = {
                        "N": N,
                        "A": A,
                        "K": K,
                        "u": u,
                        "f": f_cost,
                        "c": c_cost,
                        "d": d_demand,
                        "O": O_origin,
                        "D": D_dest,
                        "num_nodes": num_nodes,
                        "num_arcs": num_arcs,
                        "num_commodities": num_commodities,
                    }

    return problems


def process_problems(problems: Dict[str, Dict]) -> List[Dict]:
    """
    Process (filter, transform) the loaded MCND data.
    We create a list of dictionaries that includes 'args' for the MCND model.
    """
    modified_problems = []

    # Example filtering: only keep instances whose number of nodes is in [10, 200].
    for instance_name, data in tqdm(problems.items(), desc="Processing problems"):
        num_nodes = data["num_nodes"]
        if num_nodes < 20 or num_nodes > 1000:
            continue

        logging.info(
            f"Processing instance: {instance_name}, "
            f"#Nodes: {num_nodes}, #Arcs: {data['num_arcs']}, #Commodities: {data['num_commodities']}"
        )

        # Convert sets to lists so they are pickle-friendly
        N_list = list(data["N"])
        A_list = list(data["A"])
        K_list = list(data["K"])

        # The 'args' key must match the signature of create_mcnd_model (Pyomo-based).
        # We'll store c, f, u, d, O, D, plus N, A, K for clarity:
        modified_problems.append(
            {
                "name": instance_name,
                "num_nodes": data["num_nodes"],
                "num_arcs": data["num_arcs"],
                "num_commodities": data["num_commodities"],
                "args": {
                    "N": N_list,
                    "A": A_list,
                    "K": K_list,
                    "c": data["c"],
                    "f": data["f"],
                    "u": data["u"],
                    "d": data["d"],
                    "O": data["O"],
                    "D": data["D"],
                },
            }
        )

    return modified_problems


def save_to_pickle(data: List[Dict], output_path: str) -> None:
    """
    Save data to a pickle file.
    """
    try:
        logging.info(f"Saving data to {output_path}...")
        with open(output_path, "wb") as file:
            pickle.dump(data, file)
        logging.info("Data successfully saved.")
    except IOError as e:
        logging.error(f"Failed to save data: {e}")
        raise


def main():
    # Constants
    BASE_URL = "https://commalab.di.unipi.it/files/Data/MMCF/"
    DATASETS = [
        # "C", "CPlus",
        "R"
    ]
    DOWNLOAD_DIR = "data/mcnd"
    EXTRACT_PATH = "data/mcnd/extracted"
    PICKLE_PATH = "data/mcnd.pkl"
    VALIDATION_SPLIT = 0.9

    random.seed(42)  # For reproducibility

    # Ensure directories exist
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    os.makedirs(EXTRACT_PATH, exist_ok=True)
    os.makedirs(os.path.dirname(PICKLE_PATH), exist_ok=True)

    # 1. Download and Extract all datasets
    for dataset_name in DATASETS:
        filename = dataset_name + ".tgz"
        url = BASE_URL + filename
        tgz_path = os.path.join(DOWNLOAD_DIR, filename)

        # Download
        download_file(url, tgz_path)

        # Extract
        extract_target = os.path.join(EXTRACT_PATH, dataset_name)
        os.makedirs(extract_target, exist_ok=True)
        extract_tar_gz(tgz_path, extract_target)

    # 2. Parse the .dow files
    problems = decompress_and_load_problems(EXTRACT_PATH)

    # 3. Process (filter, transform) the data
    modified_problems = process_problems(problems)

    # Sort from small to large by number of nodes (optional)
    modified_problems.sort(key=lambda x: x["num_nodes"])

    logging.info(f"Number of processed MCND instances: {len(modified_problems)}")

    # Shuffle and split problems into training and validation sets
    random.seed(42)
    random.shuffle(modified_problems)  # Shuffle the list in place

    total_problems = len(modified_problems)
    validation_count = int(total_problems * VALIDATION_SPLIT)
    training_count = total_problems - validation_count

    training_problems = modified_problems[:training_count]
    validation_problems = modified_problems[training_count:]

    logging.info(f"Training instances: {len(training_problems)}")
    logging.info(f"Validation instances: {len(validation_problems)}")

    # 4. Save processed data to pickle files
    # Save training problems to the original pickle file
    save_to_pickle(training_problems, PICKLE_PATH)

    # Create a new file name for the validation problems: original file name + '_val.pkl'
    base_filename = os.path.splitext(os.path.basename(PICKLE_PATH))[0]
    valid_output_path = os.path.join(os.path.dirname(PICKLE_PATH), base_filename + "_val.pkl")
    save_to_pickle(validation_problems, valid_output_path)

    # 5. Cleanup: remove .tgz files and the extracted folder (if desired)
    shutil.rmtree(DOWNLOAD_DIR)
    logging.info("All done!")


if __name__ == "__main__":
    main()
