import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    junctions = data["junctions"]  # e.g. ["s1", "s2", ...]
    hubs = data["hubs"]  # e.g. ["h1", "h2", ...]
    pois = data["pois"]  # e.g. ["p1", "p2", ...]

    nS = len(junctions)
    M = len(hubs)
    nP = len(pois)
    N = data["num_existing_hubs"]  # first N hubs are existing
    U = data["max_new_hubs"]

    # Demand: v[s][p]  (nS x nP)
    v = [[data["demand"][junctions[s]][pois[p]] for p in range(nP)] for s in range(nS)]

    # Feasibility: F[s][h][p]  (nS x M x nP)
    # F_{shp} = 1 iff all four conditions hold:
    #   (1) car_time_sh[s][h] + bike_time_hp[h][p] - car_time_sp[s][p] <= Delta
    #   (2) bike_time_hp[h][p] <= max_bike_time
    #   (3) distance_hp[h][p] >= min_hub_poi_distance
    #   (4) distance_sp[s][p] - distance_sh[s][h] >= min_distance_diff
    T = data["max_bike_time"]
    Delta = data["max_additional_time"]
    tau = data["min_distance_diff"]

    F = []
    for s in range(nS):
        F_s = []
        for h in range(M):
            F_sh = []
            for p in range(nP):
                extra_time = (
                    data["car_time_sh"][junctions[s]][hubs[h]]
                    + data["bike_time_hp"][hubs[h]][pois[p]]
                    - data["car_time_sp"][junctions[s]][pois[p]]
                )
                bike_time = data["bike_time_hp"][hubs[h]][pois[p]]
                dist_hp = data["distance_hp"][hubs[h]][pois[p]]
                dist_saving = (
                    data["distance_sp"][junctions[s]][pois[p]]
                    - data["distance_sh"][junctions[s]][hubs[h]]
                )
                if (
                    extra_time <= Delta
                    and bike_time <= T
                    and dist_hp >= data["min_hub_poi_distance"]
                    and dist_saving >= tau
                ):
                    F_sh.append(1)
                else:
                    F_sh.append(0)
            F_s.append(F_sh)
        F.append(F_s)

    params = {
        "N": N,
        "M": M,
        "nP": nP,
        "nS": nS,
        "v": v,
        "F": F,
        "U": U,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
