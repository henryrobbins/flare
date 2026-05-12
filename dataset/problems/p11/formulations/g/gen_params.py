import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    params = {
        "T": data["T"],
        "n_G": data["n_G"],
        "n_W": data["n_W"],
        "n_S": data["n_S"],
        "ell": data["ell"],
        "C_su": data["C_su"],
        "n_L": data["n_L"],
        "P": data["P"],
        "C": data["C"],
        "C_fixed": data["C_fixed"],
        "L": data["L"],
        "R": data["R"],
        "P_min": data["P_min"],
        "P_max": data["P_max"],
        "P_wind_min": data["P_wind_min"],
        "P_wind_max": data["P_wind_max"],
        "RU": data["RU"],
        "RD": data["RD"],
        "SU": data["SU"],
        "SD": data["SD"],
        "U": data["U"],
        "D": data["D"],
        "MR": data["MR"],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
