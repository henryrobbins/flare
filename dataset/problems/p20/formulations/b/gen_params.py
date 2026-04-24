import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    foods = data["foods"]
    nutrients = data["nutrients"]
    beneficiary_nodes = data["beneficiary_nodes"]
    paths = data["paths"]

    nK = len(foods)
    nL = len(nutrients)
    nB = len(beneficiary_nodes)
    nP = len(paths)

    # c[p][k] = shipping cost per kg of commodity k along path p
    path_costs = data["path_costs"]
    c = [
        [path_costs[paths[p]][foods[k]] for k in range(nK)]
        for p in range(nP)
    ]

    # q[k] = procurement cost per kg of commodity k
    procurement_costs = data["procurement_costs"]
    q = [procurement_costs[foods[k]] for k in range(nK)]

    # nutval[k][l] = nutritional value per kg of commodity k for nutrient l
    nutritional_values = data["nutritional_values"]
    nutval = [
        [nutritional_values[foods[k]][nutrients[l]] for l in range(nL)]
        for k in range(nK)
    ]

    # nutreq[l] = per-person requirement for nutrient l
    nutritional_requirements = data["nutritional_requirements"]
    nutreq = [nutritional_requirements[nutrients[l]] for l in range(nL)]

    # dem[j] = number of beneficiaries at beneficiary camp j
    demand = data["demand"]
    dem = [demand[beneficiary_nodes[j]] for j in range(nB)]

    # e[j][p] = 1 if path p ends at beneficiary camp j, 0 otherwise
    path_end_indicators = data["path_end_indicators"]
    e = [
        [path_end_indicators[beneficiary_nodes[j]][paths[p]] for p in range(nP)]
        for j in range(nB)
    ]

    params = {
        "nP": nP,
        "nK": nK,
        "nL": nL,
        "nB": nB,
        "c": c,
        "q": q,
        "nutval": nutval,
        "nutreq": nutreq,
        "dem": dem,
        "e": e,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
