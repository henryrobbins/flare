import argparse
import json


def main(output_path: str) -> None:
    params = {
        "D": 500,
        "J": 750,
        "A": 100000,
        "O": 4,
        "Q": 10,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.output)
