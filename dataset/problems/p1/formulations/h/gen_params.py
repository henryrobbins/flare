import argparse
import json


def main(output_path: str) -> None:
    params = {
        "G": 30,
        "Y": 40,
        "K": 0.5,
        "V": 2000,
        "L": 15,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.output)
