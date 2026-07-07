import argparse
import json
from collections import Counter


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    W = data["W"]
    l = data["l"]

    counts = Counter(l)
    sizes = sorted(counts.keys(), reverse=True)

    params = {
        "W": W,
        "m": len(sizes),
        "w": sizes,
        "b": [counts[s] for s in sizes],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
