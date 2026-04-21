import numpy as np
import random
import json

def generate_data(seed, output_path='src/datasets/blood_bank_netherlands/large_data.json'):
    """
    Generate a synthetic dataset for the blood bank DC-hospital allocation problem.
    Output keys: dc_locations, hospitals, n_dcs, travel_times, travel_time_limit, feasibility_indicator
    Always writes to a JSON file (default: 'blood_bank_data.json').
    """

    np.random.seed(seed)
    random.seed(seed)

    # Problem size parameters
    num_hospitals = 1000  # total number of hospitals (increased)
    num_candidates = 200  # number of candidate DC locations (increased)
    n_dcs = 50           # number of DCs to open (increased)
    travel_time_limit = 60  # max allowed travel time in minutes

    # Generate hospital and candidate DC indices
    hospitals = [f"H{j+1}" for j in range(num_hospitals)]
    dc_locations = sorted(random.sample(hospitals, num_candidates))  # DCs are a subset of hospitals

    # Generate random coordinates for hospitals (simulate locations in NL)
    coords = {h: (np.random.uniform(0, 100), np.random.uniform(0, 100)) for h in hospitals}

    # Generate travel times (travel_times[dc][hospital])
    travel_times = {dc: {} for dc in dc_locations}
    for dc in dc_locations:
        for h in hospitals:
            dist = np.linalg.norm(np.array(coords[dc]) - np.array(coords[h]))
            travel_time = int(np.round(dist * 1.2 + np.random.uniform(5, 15)))
            travel_times[dc][h] = travel_time

    # Feasibility indicator: 1 if travel time is feasible, 0 otherwise
    feasibility_indicator = {dc: {} for dc in dc_locations}
    for dc in dc_locations:
        for h in hospitals:
            feasibility_indicator[dc][h] = int(travel_times[dc][h] <= travel_time_limit)

    data = {
        'dc_locations': dc_locations,
        'hospitals': hospitals,
        'n_dcs': n_dcs,
        'travel_times': travel_times,
        'travel_time_limit': travel_time_limit,
        'feasibility_indicator': feasibility_indicator
    }

        
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)

if __name__ == "__main__":
    # Example usage: generate and print a sample dataset
    generate_data(seed=42)

