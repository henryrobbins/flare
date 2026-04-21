import random
import numpy as np
import json

def generate_data(seed=42, output_path='src/datasets/timor_leste/large_data.json'):
    random.seed(seed)
    np.random.seed(seed)

    # Problem size parameters (LARGER DATASET)
    n = random.randint(100, 200)  # Number of households (larger)
    m = random.randint(10, 20)    # Number of existing hospitals (larger)
    num_new_sites = random.randint(20, 40)  # Number of candidate hospital sites (larger)
    S = round(random.uniform(8, 15), 2)   # Max allowed travel distance (km)
    p = min(random.randint(5, num_new_sites), num_new_sites)  # Max new hospitals to open (at least 5)

    # Sets (string IDs)
    households = [f"H{i+1}" for i in range(n)]
    existing_hospitals = [f"EJ{i+1}" for i in range(m)]
    candidate_hospitals = [f"CJ{i+1}" for i in range(num_new_sites)]
    all_hospitals = existing_hospitals + candidate_hospitals

    # Assign random coordinates
    household_coords = np.random.uniform(0, 100, size=(n, 2))
    hospital_coords = np.random.uniform(0, 100, size=(m + num_new_sites, 2))

    # Parameters
    population = {h: int(np.random.randint(50, 500)) for h in households}

    # Compute travel distances (Euclidean, rounded)
    travel_distances = {}
    for i, h in enumerate(households):
        travel_distances[h] = {}
        for j, hosp in enumerate(all_hospitals):
            dist = np.linalg.norm(household_coords[i] - hospital_coords[j])
            travel_distances[h][hosp] = round(float(dist + np.random.uniform(-10, 10)), 2)

    # Distance indicators (1 if within S, else 0)
    distance_indicators = {}
    for h in households:
        distance_indicators[h] = {}
        for hosp in all_hospitals:
            distance_indicators[h][hosp] = int(travel_distances[h][hosp] <= S)

    data = {
        'households': households,
        'existing_hospitals': existing_hospitals,
        'candidate_hospitals': candidate_hospitals,
        'all_hospitals': all_hospitals,
        'population': population,
        'travel_distances': travel_distances,
        'distance_indicators': distance_indicators,
        'max_travel_distance': S,
        'max_new_hospitals': p
    }

    if output_path:
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Data written to {output_path}")
    return data

if __name__ == "__main__":
    generate_data() 