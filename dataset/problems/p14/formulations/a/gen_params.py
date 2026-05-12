import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    nS = data["nS"]
    nH = data["nH"]
    T = data["T"]
    T_limit = data["T_limit"]
    delta = [[1 if T[i][j] <= T_limit else 0 for j in range(nH)] for i in range(nS)]

    params = {
        "nS": nS,
        "nH": nH,
        "n": data["n"],
        "T_limit": T_limit,
        "T": T,
        "delta": delta,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
