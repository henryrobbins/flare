import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    blocks = data["blocks"]   # 1-based list, e.g. [1, 2, ..., n]
    periods = data["periods"] # 1-based list, e.g. [1, 2, ..., t]
    n = len(blocks)
    t = len(periods)

    # Convert 1-based dict-of-dicts to 0-based lists
    g = [data["grade"][str(i)] for i in blocks]
    O = [data["ore_tonnage"][str(i)] for i in blocks]
    W = [data["waste_tonnage"][str(i)] for i in blocks]

    # c[i][tau]: 0-based, shape [n][t]
    c = [
        [data["npv"][str(i)][str(tau)] for tau in periods]
        for i in blocks
    ]

    # P[i][j]: 0-based, shape [n][n]
    P = [
        [data["precedence"][str(i)][str(j)] for j in blocks]
        for i in blocks
    ]

    params = {
        "n": n,
        "t": t,
        "c": c,
        "g": g,
        "O": O,
        "W": W,
        "G_min": data["grade_min"],
        "G_max": data["grade_max"],
        "PC_min": data["processing_capacity_min"],
        "PC_max": data["processing_capacity_max"],
        "MC_min": data["mining_capacity_min"],
        "MC_max": data["mining_capacity_max"],
        "P": P,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
