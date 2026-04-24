import json
import gurobipy as gp
from gurobipy import GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = gp.Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    K = data["K"]
    N = data["N"]
    d = data["d"]
    d0 = data["d0"]
    dH = data["dH"]
    v = data["v"]
    tau_min = data["tau_min"]
    tau_max = data["tau_max"]

    # Parameter Validation
    assert all(d[i][j] > 0 for i in range(N) for j in range(N) if i != j)
    assert all(
        d0[k][i] <= d0[k][j] + d[j][i]
        for k in range(K)
        for i in range(N)
        for j in range(N)
    )
    assert all(
        d[i][j] <= d[i][m] + d[m][j]
        for i in range(N)
        for j in range(N)
        for m in range(N)
    )
    assert all(tau_min[i] >= 0 for i in range(N))
    assert all(tau_max[i] >= 0 for i in range(N))

    # Definitions
    EST = [max(tau_min[i], min(v[k] + d0[k][i] for k in range(K))) for i in range(N)]
    A_minus = {
        (i, j)
        for i in range(N)
        for j in range(N)
        if EST[i] + d[i][i] + d[i][j] > tau_max[j]
    }
    Q = [
        (i, k, j)
        for i in range(N)
        for k in range(N)
        for j in range(N)
        if i != k
        and k != j
        and (i, k) not in A_minus
        and (k, j) not in A_minus
        and max(EST[k], EST[i] + d[i][i] + d[i][k]) + d[k][k] + d[k][j] > tau_max[j]
    ]
    M = 2 * max(d[i][j] for i in range(N) for j in range(N))

    # Variables
    x = model.addVars(K + N, K + N, vtype=GRB.INTEGER, name="x")
    delta = model.addVars(N, vtype=GRB.CONTINUOUS, name="delta")

    # Constraints
    model.addConstrs(
        gp.quicksum(x[u, v] for v in range(K + N)) == 1 for u in range(K + N)
    )
    model.addConstrs(
        gp.quicksum(x[v, u] for v in range(K + N)) == 1 for u in range(K + N)
    )
    model.addConstrs(
        delta[i] - gp.quicksum((d0[k][i] + v[k]) * x[k, K + i] for k in range(K)) >= 0
        for i in range(N)
    )
    model.addConstrs(
        delta[j]
        - delta[i]
        - M * x[K + i, K + j]
        + (d[i][i] + d[i][j]) * x[K + i, K + i]
        >= d[i][i] + d[i][j] - M
        for i in range(N)
        for j in range(N)
    )
    model.addConstrs(delta[i] >= tau_min[i] for i in range(N))
    model.addConstrs(delta[i] <= tau_max[i] for i in range(N))
    for i, k, j in Q:
        model.addConstr(x[K + i, K + k] + x[K + k, K + j] + x[K + k, K + k] <= 1)

    # Objective
    model.setObjective(
        gp.quicksum(d0[k][i] * x[k, K + i] for k in range(K) for i in range(N))
        + gp.quicksum(d[i][j] * x[K + i, K + j] for i in range(N) for j in range(N))
        + gp.quicksum(dH[k][i] * x[K + i, k] for i in range(N) for k in range(K)),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(K + N)] for i in range(K + N)]
    variables["delta"] = [delta[i].x for i in range(N)]
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
