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
    paths = data["paths"]

    nN = len(all_nodes)
    nS = len(supplier_nodes)
    nT = len(transshipment_nodes)
    nB = len(beneficiary_nodes)
    nP = len(paths)
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

    # pE[p][i][j] = 1 if edge (i -> j) is part of path p
    # pRank[p][v] = position of node v in path p (0 for source, increasing along edges;
    # 0 for nodes not on the path — pRank is only constrained where pE[p][i][j] = 1)
    pE = [[[0 for _ in range(nN)] for _ in range(nN)] for _ in range(nP)]
    pRank = [[0 for _ in range(nN)] for _ in range(nP)]
    for p in range(nP):
        path_node_names = paths[p].split("-")
        path_node_indices = [node_index[name] for name in path_node_names]
        for pos, v in enumerate(path_node_indices):
            pRank[p][v] = pos
        for idx in range(len(path_node_indices) - 1):
            i = path_node_indices[idx]
            j = path_node_indices[idx + 1]
            pE[p][i][j] = 1

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
        "nN": nN,
        "nS": nS,
        "nT": nT,
        "nB": nB,
        "nP": nP,
        "nK": nK,
        "nL": nL,
        "S": S,
        "T": T,
        "B": B,
        "E": E,
        "pE": pE,
        "pRank": pRank,
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
