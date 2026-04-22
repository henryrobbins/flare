import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    params = {
        "K": data["K"],
        "N": data["N"],
        "d": data["d"],
        "d0": data["d0"],
        "dH": data["dH"],
        "v": data["v"],
        "tau_min": data["tau_min"],
        "tau_max": data["tau_max"],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
