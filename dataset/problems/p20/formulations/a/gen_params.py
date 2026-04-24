import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    all_nodes = data["all_nodes"]
    foods = data["foods"]
    nutrients = data["nutrients"]

    nN = len(all_nodes)
    nK = len(foods)
    nL = len(nutrients)

    node_type = data.get("node_type", None)
    beneficiary_nodes = set(data["beneficiary_nodes"])

    # isB[j] = 1 if node j is a beneficiary camp, 0 otherwise
    isB = [1 if all_nodes[j] in beneficiary_nodes else 0 for j in range(nN)]

    # E[i][j] = 1 if edge (i -> j) exists
    edges = data["edges"]
    E = [
        [edges[all_nodes[i]][all_nodes[j]] for j in range(nN)]
        for i in range(nN)
    ]

    # dem[j] = number of beneficiaries at node j (0 for non-beneficiary nodes)
    demand = data["demand"]
    dem = [demand.get(all_nodes[j], 0) for j in range(nN)]

    # pc[k] = procurement cost per kg of commodity k
    procurement_costs = data["procurement_costs"]
    pc = [procurement_costs[foods[k]] for k in range(nK)]

    # tc[i][j][k] = transportation cost per kg of commodity k along edge (i, j)
    edge_costs = data["edge_costs"]
    tc = [
        [
            [edge_costs[all_nodes[i]][all_nodes[j]][foods[k]] for k in range(nK)]
            for j in range(nN)
        ]
        for i in range(nN)
    ]

    # nutreq[l] = per-person requirement for nutrient l
    nutritional_requirements = data["nutritional_requirements"]
    nutreq = [nutritional_requirements[nutrients[l]] for l in range(nL)]

    # nutval[k][l] = nutritional value per kg of commodity k for nutrient l
    nutritional_values = data["nutritional_values"]
    nutval = [
        [nutritional_values[foods[k]][nutrients[l]] for l in range(nL)]
        for k in range(nK)
    ]

    params = {
        "nN": nN,
        "nK": nK,
        "nL": nL,
        "isB": isB,
        "E": E,
        "dem": dem,
        "pc": pc,
        "tc": tc,
        "nutreq": nutreq,
        "nutval": nutval,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
