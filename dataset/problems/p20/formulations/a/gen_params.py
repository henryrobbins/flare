import json
import argparse


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    all_nodes = data["all_nodes"]
    supplier_nodes = data["supplier_nodes"]
    transshipment_nodes = data["transshipment_nodes"]
    beneficiary_nodes = data["beneficiary_nodes"]
    foods = data["foods"]
    nutrients = data["nutrients"]

    nN = len(all_nodes)
    nS = len(supplier_nodes)
    nT = len(transshipment_nodes)
    nB = len(beneficiary_nodes)
    nK = len(foods)
    nL = len(nutrients)

    node_index = {node: idx for idx, node in enumerate(all_nodes)}

    # S[s] = index in all_nodes of supplier s
    S = [node_index[supplier_nodes[s]] for s in range(nS)]

    # T[t] = index in all_nodes of transshipment node t
    T = [node_index[transshipment_nodes[t]] for t in range(nT)]

    # B[j] = index in all_nodes of beneficiary camp j
    B = [node_index[beneficiary_nodes[j]] for j in range(nB)]

    # E[i][j] = 1 if edge (i -> j) exists
    edges = data["edges"]
    E = [
        [edges[all_nodes[i]][all_nodes[j]] for j in range(nN)]
        for i in range(nN)
    ]

    # dem[j] = number of beneficiaries at beneficiary camp j
    demand = data["demand"]
    dem = [demand[beneficiary_nodes[j]] for j in range(nB)]

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
        "nS": nS,
        "nT": nT,
        "nB": nB,
        "nK": nK,
        "nL": nL,
        "S": S,
        "T": T,
        "B": B,
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
