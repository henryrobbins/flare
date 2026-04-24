import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    hubs = data["H"]       # list of hub name strings, e.g. ["hub_1", "hub_2", ...]
    regions = data["C"]    # list of region name strings, e.g. ["region_1", "region_2", ...]
    nH = len(hubs)
    nC = len(regions)

    # a: affected population per region, indexed 0..nC-1
    # data["a"] is a dict keyed by region name string (second formulation field)
    a_raw = data["a"]
    a = [a_raw[regions[c]] for c in range(nC)]

    # C: cost per person from hub h to region c, shape [nH][nC]
    # data["C_alt"] is a dict keyed by string repr of (hub, region) tuple,
    # e.g. "('hub_1', 'region_1')"
    C_alt_raw = data["C_alt"]
    C = [
        [C_alt_raw[f"('{hubs[h]}', '{regions[c]}')"] for c in range(nC)]
        for h in range(nH)
    ]

    # t: travel time from hub h to region c, shape [nH][nC]
    t_raw = data["t"]
    t = [
        [t_raw[f"('{hubs[h]}', '{regions[c]}')"] for c in range(nC)]
        for h in range(nH)
    ]

    # Hf: fixed-hub binary indicator, shape [nH]
    fixed_set = set(data["H_fixed"])
    Hf = [1 if hubs[h] in fixed_set else 0 for h in range(nH)]

    params = {
        "nH": nH,
        "nC": nC,
        "a": a,
        "C": C,
        "t": t,
        "T": data["T"],
        "n": data["n"],
        "Hf": Hf,
        "M": data["M"],
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
