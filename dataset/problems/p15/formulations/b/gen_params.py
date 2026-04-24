import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    sectors = data["sectors"]           # list of sector names, length nI
    areas = data["areas"]               # list of area values, length nJ
    owners = data["owners"]             # list of owner names, length nH
    configs = data["floor_configurations"]  # list of config names, length nV

    nI = len(sectors)
    nJ = len(areas)
    nH = len(owners)
    nV = len(configs)
    nK = data["total_floors"]           # number of floors (K in problem.json)

    # area index lookup: area value -> index in areas list
    area_to_idx = {a: idx for idx, a in enumerate(areas)}

    # cap[v]: number of apartments in configuration v
    apc = data["apartments_per_config"]
    cap = [apc[configs[v]] for v in range(nV)]

    nA = max(cap)  # maximum apartments across all configurations

    # jApt[v][a]: area index of apartment a in configuration v
    # apartment_area[config_name] is a dict from apt_id (e.g. "apt1") -> area value
    apt_area = data["apartment_area"]
    jApt = []
    for v in range(nV):
        cfg = configs[v]
        n_apts = cap[v]
        row = []
        for a in range(n_apts):
            apt_id = f"apt{a + 1}"
            area_val = apt_area[cfg][apt_id]
            row.append(area_to_idx[area_val])
        # Pad to nA with 0 (entries beyond cap[v] are never accessed in the model)
        row.extend([0] * (nA - n_apts))
        jApt.append(row)

    # pProfit[i][j][h]: profit for sector i, area index j, owner h
    # Same data as O in formulation a, but keyed by area index rather than area value
    ppa = data["profit_per_apartment"]
    pProfit = [
        [
            [ppa[sectors[i]][str(areas[j])][owners[h]] for h in range(nH)]
            for j in range(nJ)
        ]
        for i in range(nI)
    ]

    # area[j]: actual floor area value for area index j
    area = areas  # already a list of numbers

    # m[i][h]: minimum area for sector i, owner h
    mar = data["min_area_requirement"]
    m = [
        [mar[sectors[i]][owners[h]] for h in range(nH)]
        for i in range(nI)
    ]

    # b[i]: minimum fraction of apartments in sector i (same as a[i] in formulation a)
    msp = data["min_sector_percentage"]
    b = [msp[sectors[i]] for i in range(nI)]

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
        "nK": nK,
        "nV": nV,
        "nH": nH,
        "nI": nI,
        "nJ": nJ,
        "nA": nA,
        "cap": cap,
        "jApt": jApt,
        "pProfit": pProfit,
        "area": area,
        "m": m,
        "b": b,
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
