import tarfile
import requests
import os
import gzip
import tsplib95
from tqdm import tqdm
from typing import Dict, List
import pickle
import logging
import shutil
import random

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")


def download_file(url: str, output_path: str) -> None:
    """Download a file from a given URL and save it to the specified path."""
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
    """Extract a .tar.gz file to the specified directory."""
    try:
        logging.info(f"Extracting {file_path} to {extract_path}...")
        with tarfile.open(file_path, "r:gz") as tar:
            tar.extractall(extract_path)
        logging.info("Extraction completed successfully.")
    except tarfile.TarError as e:
        logging.error(f"Failed to extract file: {e}")
        raise


def decompress_and_load_problems(
    base_path: str,
) -> Dict[str, Dict[str, tsplib95.models.StandardProblem]]:
    """Decompress .gz files and load them using tsplib95."""
    problems: Dict[str, Dict[str, tsplib95.models.StandardProblem]] = {}

    for filename in os.listdir(base_path):
        if filename.endswith(".gz"):
            gz_file_path = os.path.join(base_path, filename)
            decompressed_file_path = os.path.splitext(gz_file_path)[0]

            try:
                # Decompress the file
                with gzip.open(gz_file_path, "rt") as gz_file:
                    content = gz_file.read()

                # Save the decompressed content to a new file
                with open(decompressed_file_path, "w") as decompressed_file:
                    decompressed_file.write(content)

                # Load the decompressed file with tsplib95
                problem = tsplib95.load(decompressed_file_path)
                problem_name = os.path.basename(decompressed_file_path).split(".")[0]
                problem_type = os.path.basename(decompressed_file_path).split(".")[-1]

                if problem_name not in problems:
                    problems[problem_name] = {}

                if problem_type == "tour":
                    problems[problem_name]["tour"] = problem
                elif problem_type == "tsp":
                    problems[problem_name]["tsp"] = problem

            except (gzip.BadGzipFile, IOError) as e:
                logging.error(f"Failed to process {filename}: {e}")
                continue

    return problems


def process_problems(problems: Dict[str, Dict[str, tsplib95.models.StandardProblem]]) -> List[Dict]:
    """Process the loaded problems and extract relevant data."""
    modified_problems = []

    for problem_name, problem_data in tqdm(problems.items(), desc="Processing problems"):
        if "tsp" in problem_data:
            p = problem_data["tsp"]
            t = problem_data["tour"] if "tour" in problem_data.keys() else None
            NODES = list(p.get_nodes())
            TOURS = list(t.tours) if t else None
            if len(NODES) < 20 or len(NODES) > 250:
                continue
            # Adjust nodes to be 1-indexed if they are 0-indexed
            if 0 in NODES:
                NODES = [node + 1 for node in NODES]
                C = {
                    (edge[0] + 1, edge[1] + 1): p.get_weight(*edge) for edge in list(p.get_edges())
                }
            else:
                C = {edge: p.get_weight(*edge) for edge in list(p.get_edges())}

            logging.info(f"Processing problem: {problem_name}")
            logging.info(f"Number of nodes: {len(NODES)}")
            modified_problems.append(
                {
                    "name": problem_name,
                    "NODES": NODES,
                    "TOURS": TOURS[0] if t else None,
                    "args": {"n": len(NODES), "c": C},
                }
            )

    return modified_problems


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


def main():
    # Constants
    FILE_URL = "http://comopt.ifi.uni-heidelberg.de/software/TSPLIB95/tsp/ALL_tsp.tar.gz"
    TAR_GZ_PATH = "data/ALL_tsp.tar.gz"
    EXTRACT_PATH = "data/tmp/"
    PICKLE_PATH = "data/tsp.pkl"
    VALIDATION_SPLIT = 0.9  # 80% of the problems will be used for validation

    # Ensure directories exist
    os.makedirs(EXTRACT_PATH, exist_ok=True)
    os.makedirs(os.path.dirname(PICKLE_PATH), exist_ok=True)

    # Download and extract the file
    download_file(FILE_URL, TAR_GZ_PATH)
    extract_tar_gz(TAR_GZ_PATH, EXTRACT_PATH)

    # Decompress and load problems
    problems = decompress_and_load_problems(EXTRACT_PATH)

    # Process problems
    modified_problems = process_problems(problems)

    # Sort problems from small to large based on the number of nodes
    modified_problems.sort(key=lambda x: len(x["NODES"]))

    logging.info(f"Number of processed problems: {len(modified_problems)}")

    # Shuffle problems before splitting into training and validation sets
    random.seed(14)
    random.shuffle(modified_problems)

    # Split problems into training and validation sets
    total_problems = len(modified_problems)
    validation_count = int(total_problems * VALIDATION_SPLIT)
    training_count = total_problems - validation_count

    training_problems = modified_problems[:training_count]
    validation_problems = modified_problems[training_count:]

    logging.info(f"Training problems: {len(training_problems)}")
    logging.info(f"Validation problems: {len(validation_problems)}")

    # Save training problems to the original pickle file
    save_to_pickle(training_problems, PICKLE_PATH)

    # Create a new file name for the validation problems: original file name + '_val.pickle'
    base_filename = os.path.splitext(os.path.basename(PICKLE_PATH))[0]
    valid_output_path = os.path.join(os.path.dirname(PICKLE_PATH), base_filename + "_val.pkl")
    save_to_pickle(validation_problems, valid_output_path)

    # Remove temporary files
    os.remove(TAR_GZ_PATH)
    shutil.rmtree(EXTRACT_PATH)


if __name__ == "__main__":
    main()
