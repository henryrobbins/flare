def generate_data(seed):
    import numpy as np
    import random
    np.random.seed(seed)
    random.seed(seed)

    # Problem size
    num_flights = 8
    num_airports = 4
    num_sectors = 5
    num_time_periods = 12
    max_path_length = 4
    min_path_length = 3
    max_turnarounds = 3

    # Sets
    F = [f"F{f}" for f in range(num_flights)]
    X = [f"A{k}" for k in range(num_airports)]
    J = [f"S{j}" for j in range(num_sectors)]
    T = list(range(num_time_periods))

    # Flight paths: Each flight has a path (origin, sectors..., destination)
    P_f = {}
    N_f = {}
    l_fj = {}  # time spent by flight f in sector j
    for f in F:
        origin = random.choice(X)
        destination = random.choice([a for a in X if a != origin])
        path_length = random.randint(min_path_length, max_path_length)
        
        # Choose adjacent sectors
        start_idx = random.randint(0, len(J) - (path_length - 2))
        sectors = J[start_idx:start_idx + (path_length - 2)]
        
        path = [origin] + sectors + [destination]
        P_f[f] = path
        N_f[f] = len(path)
        
        for j in path[1:-1]:  # Only for sectors, not airports
            l_fj[(f, j)] = np.random.randint(1, 3)  # 1 or 2 time units
        # For completeness, set l_fj for airports to 0
        l_fj[(f, origin)] = 0
        l_fj[(f, destination)] = 0

    # Feasible times for each flight to arrive at each sector
    T_fj = {}
    for f in F:
        for idx, j in enumerate(P_f[f]):
            # For each sector/airport in path, feasible arrival times
            earliest = idx  # can't arrive before idx
            latest = num_time_periods - (N_f[f] - idx)
            T_fj[(f, j)] = list(range(max(0, earliest), max(earliest+1, min(num_time_periods, latest+2))))

    # Scheduled departure and arrival times
    d_f = {}
    r_f = {}
    sigma_f = {}
    for f in F:
        dep_time = np.random.randint(0, num_time_periods // 2)
        d_f[f] = dep_time
        min_flight_time = N_f[f] + np.random.randint(0, 2)
        sigma_f[f] = min_flight_time
        arr_time = dep_time + min_flight_time
        r_f[f] = min(arr_time, num_time_periods - 1)

    # Turnaround pairs
    IC = []
    s_f = {f: np.random.randint(1, 3) for f in F}  # min turnaround time for each flight
    for _ in range(max_turnarounds):
        f1, f2 = random.sample(F, 2)
        if (f1, f2) not in IC and r_f[f1] < d_f[f2]:
            IC.append((f1, f2))

    # Costs
    c_fg = {f: np.random.randint(5, 15) for f in F}  # ground hold cost
    c_fa = {f: np.random.randint(15, 30) for f in F}  # air hold cost
    c_g = np.random.randint(5, 15)
    c_a = np.random.randint(15, 30)

    # Airport capacities
    D_kt = {}
    A_kt = {}
    for k in X:
        for t in T:
            D_kt[(k, t)] = np.random.randint(2, 5)
            A_kt[(k, t)] = np.random.randint(2, 5)

    # For each flight, feasible departure and arrival times
    T_fd = {f: list(range(max(0, d_f[f] - 1), min(num_time_periods, d_f[f] + 3))) for f in F}
    T_fa = {f: list(range(max(0, r_f[f] - 2), min(num_time_periods, r_f[f] + 3))) for f in F}

    # Departure and arrival airports for each flight
    P_f_1 = {f: P_f[f][0] for f in F}
    P_f_2 = {f: P_f[f][-1] for f in F}

    # Assemble data dictionary
    data = {
        # Sets
        'F': F,
        'X': X,
        'J': J,
        'T': T,
        'IC': IC,
        'P_f': P_f,
        'N_f': N_f,
        'T_fj': T_fj,
        'T_fd': T_fd,
        'T_fa': T_fa,
        # Parameters
        'd_f': d_f,
        'r_f': r_f,
        'S_f': s_f,
        'sigma_f': sigma_f,
        'c_fg': c_fg,
        'c_fa': c_fa,
        'c_g': c_g,
        'c_a': c_a,
        'l_fj': l_fj,
        'D_kt': D_kt,
        'A_kt': A_kt,
        'P_f_1': P_f_1,
        'P_f_2': P_f_2
    }
    data_keys_explanation = {
        'F': 'Set of all flights in the air traffic network',
        'X': 'Set of all airports in the network',
        'J': 'Set of all air traffic control sectors',
        'T': 'Set of discrete time periods in the planning horizon',
        'IC': 'Set of flight pairs that require turnaround operations',
        'P_f': 'For each flight f, its complete route through the network including origin airport, intermediate sectors, and destination airport',
        'N_f': 'For each flight f, the number of sectors in its route',
        'T_fj': 'For each flight f and sector j, the set of time periods when the flight can arrive at that sector',
        'T_fd': 'For each flight f, the set of time periods when it can depart from its origin airport',
        'T_fa': 'For each flight f, the set of time periods when it can arrive at its destination airport',
        'd_f': 'For each flight f, its originally scheduled departure time period',
        'r_f': 'For each flight f, its originally scheduled arrival time period',
        'S_f': 'For each flight f, the minimum time required between its arrival and next departure (turnaround time)',
        'sigma_f': 'For each flight f, the minimum time required to complete its route',
        'c_fg': 'For each flight f, the cost per time period of ground delay at its origin airport',
        'c_fa': 'For each flight f, the cost per time period of airborne delay',
        'c_g': 'System-wide cost per time period of ground delay',
        'c_a': 'System-wide cost per time period of airborne delay',
        'l_fj': 'For each flight f and sector j, the time required to traverse that sector',
        'D_kt': 'For each airport k and time period t, the maximum number of flights that can depart',
        'A_kt': 'For each airport k and time period t, the maximum number of flights that can arrive',
        'P_f_1': 'For each flight f, its origin airport',
        'P_f_2': 'For each flight f, its destination airport'
    }

    return data, data_keys_explanation