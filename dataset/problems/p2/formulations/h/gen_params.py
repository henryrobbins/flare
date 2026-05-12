import argparse
import json


def main(output_path: str) -> None:
    params = {
        "F": 20,
        "M": 35,
        "R": 20,
        "W": 50,
        "S": 12,
        "Z": 15,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.output)
