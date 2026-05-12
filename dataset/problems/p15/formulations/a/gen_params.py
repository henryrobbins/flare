import argparse
import json


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    sectors = data["sectors"]  # list of sector names, length nI
    areas = data["areas"]  # list of area values, length nJ
    owners = data["owners"]  # list of owner names, length nH
    configs = data["floor_configurations"]  # list of config names, length nV

    nI = len(sectors)
    nJ = len(areas)
    nH = len(owners)
    nV = len(configs)
    K = data["total_floors"]

    # R[j][v]: number of apartments with area areas[j] in configuration configs[v]
    # apartments_by_area_config is keyed by area value then config name
    abyc = data["apartments_by_area_config"]
    R = [[abyc[str(areas[j])].get(configs[v], 0) for v in range(nV)] for j in range(nJ)]

    # O[i][j][h]: profit for sector i, area j, owner h
    ppa = data["profit_per_apartment"]
    O = [
        [
            [ppa[sectors[i]][str(areas[j])][owners[h]] for h in range(nH)]
            for j in range(nJ)
        ]
        for i in range(nI)
    ]

    # area[j]: actual floor area value
    area = areas  # already a list of numbers

    # m[i][h]: minimum area for sector i, owner h
    mar = data["min_area_requirement"]
    m = [[mar[sectors[i]][owners[h]] for h in range(nH)] for i in range(nI)]

    # a[i]: minimum fraction of apartments in sector i
    msp = data["min_sector_percentage"]
    a = [msp[sectors[i]] for i in range(nI)]

    # s[i]: minimum average area for sector i
    maas = data["min_avg_area_per_sector"]
    s = [maas[sectors[i]] for i in range(nI)]

    # o[h]: minimum ownership fraction for owner h
    mop = data["min_ownership_percentage"]
    o = [mop[owners[h]] for h in range(nH)]

    # iFree: index of "free" sector; hCorp: index of "corporation" owner
    iFree = sectors.index("free")
    hCorp = owners.index("corporation")

    params = {
        "nI": nI,
        "nJ": nJ,
        "nH": nH,
        "nV": nV,
        "K": K,
        "R": R,
        "O": O,
        "area": area,
        "m": m,
        "a": a,
        "s": s,
        "o": o,
        "iFree": iFree,
        "hCorp": hCorp,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
