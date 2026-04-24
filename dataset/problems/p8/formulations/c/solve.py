import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    n = data["n"]
    m = data["m"]
    p = data["p"]
    Om = data["Om"]

    # Parameter Validation
    assert all(p[j][k] >= 0 for j in range(n) for k in range(m))
    assert n >= 1 and m >= 1
    assert all(0 <= Om[j][k] < m for j in range(n) for k in range(m))
    assert all(sorted(Om[j]) == list(range(m)) for j in range(n))

    # Definitions
    P = []
    for machine in range(m):
        ops = [(j, k) for j in range(n) for k in range(m) if Om[j][k] == machine]
        for i in range(len(ops)):
            for j2, k2 in ops[i + 1 :]:
                P.append((ops[i], (j2, k2)))
    M = sum(p[j][k] for j in range(n) for k in range(m))

    # Variables
    S = model.addVars(n, m, vtype=GRB.CONTINUOUS, name="S")
    y = model.addVars(
        [(j1, k1, j2, k2) for (j1, k1), (j2, k2) in P], vtype=GRB.BINARY, name="y"
    )
    C_max = model.addVar(vtype=GRB.CONTINUOUS, name="C_max")

    # Constraints
    model.addConstrs(
        S[j, k + 1] >= S[j, k] + p[j][k] for j in range(n) for k in range(m - 1)
    )
    for (j1, k1), (j2, k2) in P:
        model.addConstr(
            S[j1, k1] + p[j1][k1] <= S[j2, k2] + M * (1 - y[j1, k1, j2, k2])
        )
    for (j1, k1), (j2, k2) in P:
        model.addConstr(S[j2, k2] + p[j2][k2] <= S[j1, k1] + M * y[j1, k1, j2, k2])
    model.addConstrs(C_max >= S[j, m - 1] + p[j][m - 1] for j in range(n))
    for machine in range(m):
        ops_m = [(j, k) for j in range(n) for k in range(m) if Om[j][k] == machine]
        load_m = sum(p[j][k] for j, k in ops_m)
        min_head = min(sum(p[j][t] for t in range(k)) for j, k in ops_m)
        min_tail = min(sum(p[j][t] for t in range(k + 1, m)) for j, k in ops_m)
        model.addConstr(C_max >= load_m + min_head + min_tail)

    # Objective
    model.setObjective(C_max, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["S"] = [[S[i, j].x for j in range(m)] for i in range(n)]
    variables["y"] = {str(list(k)): y[k].x for k in y}
    variables["C_max"] = C_max.x
    solution["variables"] = variables
    solution["objective"] = model.objVal
    with open(solution_path, "w") as f:
        json.dump(solution, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("params", help="Path to parameters.json")
    parser.add_argument("solution", help="Path to write solution.json")
    args = parser.parse_args()
    main(args.params, args.solution)
