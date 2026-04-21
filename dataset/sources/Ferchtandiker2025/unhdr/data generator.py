def generate_data(seed):
    import random
    import numpy as np

    random.seed(seed)
    np.random.seed(seed)

    # Set sizes
    num_hubs = random.randint(4, 7)  # total candidate hubs
    num_fixed_hubs = random.randint(1, min(3, num_hubs-1))  # at least 1 fixed hub
    num_regions = random.randint(5, 10)  # disaster-prone regions

    # Sets
    hubs = [f"hub_{i+1}" for i in range(num_hubs)]
    fixed_hubs = sorted(random.sample(hubs, num_fixed_hubs))
    regions = [f"region_{j+1}" for j in range(num_regions)]

    # Parameters
    # Number of people affected in each region
    a_c = {c: random.randint(1000, 10000) for c in regions}
    # Cost per person to transport from hub to region
    C_hc = {(h, c): round(random.uniform(10, 100), 2) for h in hubs for c in regions}
    # Travel time (in hours) from hub to region
    t_hc = {(h, c): random.randint(24, 96) for h in hubs for c in regions}
    # Maximum allowed travel time (e.g., 72 hours)
    T = 72
    # Maximum number of hubs that can be opened (including fixed hubs)
    n = random.randint(num_fixed_hubs+1, num_hubs)
    # Big-M constant
    M = 10000
    # Cardinality of C
    cardinality_C = num_regions

    # For alternate parameter names in the second formulation
    a = {c: a_c[c] for c in regions}
    C_alt = {(h, c): C_hc[(h, c)] for h in hubs for c in regions}
    t = {(h, c): t_hc[(h, c)] for h in hubs for c in regions}
    
    data_keys_explanation = {
    # Sets
    "H": "List of all candidate hub locations (e.g., ['hub_1', 'hub_2', ...])",
    "H_fixed": "List of hub locations that must be opened. This is a subset of all hub locations.",
    "C": "List of all disaster-prone regions (e.g., ['region_1', 'region_2', ...])",
    
    # Parameters for first formulation
    "a_c": "Dictionary mapping each region to the number of people affected in that region",
    "C_hc": "Dictionary mapping each (hub, region) pair to the cost per person for transportation",
    "t_hc": "Dictionary mapping each (hub, region) pair to the travel time in hours",
    "T": "Maximum allowed travel time (in hours) for any hub-region connection",
    "n": "Maximum number of hubs that can be opened",
    "M": "Big-M constant used in mathematical formulation",
    
    # Parameters for second formulation
    "a": "Dictionary mapping each region to the number of people affected in that region",
    "C_alt": "Dictionary mapping each (hub, region) pair to the cost per person for transportation",
    "t": "Dictionary mapping each (hub, region) pair to the travel time in hours",
    "cardinality_C": "Total number of regions"
} 

    data = {
        # Sets
        "H": hubs,
        "H_fixed": fixed_hubs,
        "C": regions,
        # Parameters for both formulations
        "a_c": a_c,  # for first formulation
        "C_hc": C_hc,  # for first formulation
        "t_hc": t_hc,  # for first formulation
        "T": T,
        "n": n,
        "M": M,
        # Parameters for second formulation
        "a": a,  # for second formulation
        "C_alt": C_alt,  # for second formulation
        "t": t,  # for second formulation
        "cardinality_C": cardinality_C
    }
    return data, data_keys_explanation