import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    households = data["households"]  # e.g. ["H1", "H2", ...]
    all_hospitals = data["all_hospitals"]  # e.g. ["EJ1", ..., "CJ1", ...]
    existing_hospitals = data["existing_hospitals"]

    nI = len(households)
    m = len(existing_hospitals)
    M = len(all_hospitals)

    v = [data["population"][h] for h in households]

    distance_indicators = data["distance_indicators"]
    a = [[distance_indicators[h][hosp] for hosp in all_hospitals] for h in households]

    params = {
        "nI": nI,
        "m": m,
        "M": M,
        "v": v,
        "a": a,
        "p": data["max_new_hospitals"],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
