import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    hubs = data["H"]  # list of hub name strings, e.g. ["hub_1", "hub_2", ...]
    regions = data[
        "C"
    ]  # list of region name strings, e.g. ["region_1", "region_2", ...]
    nH = len(hubs)
    nC = len(regions)

    # a: affected population per region, indexed 0..nC-1
    # data["a_c"] is a dict keyed by region name string
    a_c_raw = data["a_c"]
    a = [a_c_raw[regions[c]] for c in range(nC)]

    # C: cost per person from hub h to region c, shape [nH][nC]
    # data["C_hc"] is a dict keyed by string repr of (hub, region) tuple,
    # e.g. "('hub_1', 'region_1')"
    C_hc_raw = data["C_hc"]
    C = [
        [C_hc_raw[f"('{hubs[h]}', '{regions[c]}')"] for c in range(nC)]
        for h in range(nH)
    ]

    # t: travel time from hub h to region c, shape [nH][nC]
    t_hc_raw = data["t_hc"]
    t = [
        [t_hc_raw[f"('{hubs[h]}', '{regions[c]}')"] for c in range(nC)]
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
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
