import json
import argparse


def main(output_path: str) -> None:
    params = {
        "V": 3,
        "U": 4,
        "Z": 10,
        "N": 2,
        "P": 0.33,
        "C": 200,
        "E": 4,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.output)
