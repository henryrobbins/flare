import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    params = {
        "NumBeakers": data["NumBeakers"],
        "FlourAvailable": data["FlourAvailable"],
        "SpecialLiquidAvailable": data["SpecialLiquidAvailable"],
        "MaxWasteAllowed": data["MaxWasteAllowed"],
        "FlourUsagePerBeaker": data["FlourUsagePerBeaker"],
        "SpecialLiquidUsagePerBeaker": data["SpecialLiquidUsagePerBeaker"],
        "SlimeProducedPerBeaker": data["SlimeProducedPerBeaker"],
        "WasteProducedPerBeaker": data["WasteProducedPerBeaker"],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
