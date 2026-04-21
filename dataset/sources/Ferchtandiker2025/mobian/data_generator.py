import random
import numpy as np
import json

def generate_data(seed=42, output_path='src/datasets/mobian/large_data.json'):
    random.seed(seed)
    np.random.seed(seed)

    # Set sizes for a large dataset
    num_hubs = random.randint(20, 40)
    num_pois = random.randint(30, 60)
    num_junctions = random.randint(25, 50)

    hubs = [f"h{h+1}" for h in range(num_hubs)]
    pois = [f"p{p+1}" for p in range(num_pois)]
    junctions = [f"s{s+1}" for s in range(num_junctions)]

    # Generate demand
    demand = {s: {p: float(random.randint(20, 200)) for p in pois} for s in junctions}

    # Generate distances
    distance_sp = {s: {p: round(random.uniform(1, 20), 2) for p in pois} for s in junctions}
    distance_sh = {s: {h: round(random.uniform(1, 15), 2) for h in hubs} for s in junctions}
    distance_hp = {h: {p: round(random.uniform(1, 10), 2) for p in pois} for h in hubs}

    # Generate travel times
    car_time_sp = {s: {p: round(random.uniform(5, 30), 1) for p in pois} for s in junctions}
    car_time_sh = {s: {h: round(random.uniform(3, 20), 1) for h in hubs} for s in junctions}
    bike_time_hp = {h: {p: round(random.uniform(5, 25), 1) for p in pois} for h in hubs}

    # Scalar parameters
    max_bike_time = round(random.uniform(10, 20), 1)
    num_existing_hubs = random.randint(1, max(1, num_hubs // 2))
    max_new_hubs = random.randint(1, max(1, num_hubs - num_existing_hubs))
    min_hub_poi_distance = round(random.uniform(2, 5), 2)
    max_additional_time = round(random.uniform(15, 45), 1)
    min_distance_diff = round(random.uniform(1, 5), 2)

    # Feasibility
    feasibility = {}
    for s in junctions:
        feasibility[s] = {}
        for h in hubs:
            feasibility[s][h] = {}
            for p in pois:
                extra_time = car_time_sh[s][h] + bike_time_hp[h][p] - car_time_sp[s][p]
                if extra_time > max_additional_time:
                    feasibility[s][h][p] = 0
                    continue
                if bike_time_hp[h][p] > max_bike_time:
                    feasibility[s][h][p] = 0
                    continue
                if distance_hp[h][p] < min_hub_poi_distance:
                    feasibility[s][h][p] = 0
                    continue
                if (distance_sp[s][p] - distance_sh[s][h]) < min_distance_diff:
                    feasibility[s][h][p] = 0
                    continue
                feasibility[s][h][p] = 1

    data = {
        "hubs": hubs,
        "pois": pois,
        "junctions": junctions,
        "demand": demand,
        "car_time_sp": car_time_sp,
        "car_time_sh": car_time_sh,
        "bike_time_hp": bike_time_hp,
        "distance_sp": distance_sp,
        "distance_hp": distance_hp,
        "distance_sh": distance_sh,
        "max_bike_time": max_bike_time,
        "num_existing_hubs": num_existing_hubs,
        "max_new_hubs": max_new_hubs,
        "min_hub_poi_distance": min_hub_poi_distance,
        "max_additional_time": max_additional_time,
        "min_distance_diff": min_distance_diff,
        "feasibility": feasibility
    }
    
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Data written to {output_path}")

if __name__ == "__main__":
    generate_data()