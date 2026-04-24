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
    n = data["n"]
    m = data["m"]
    K = data["K"]
    tail = data["tail"]
    head = data["head"]
    c = data["c"]
    f = data["f"]
    u = data["u"]
    O = data["O"]
    D = data["D"]
    d = data["d"]

    # Parameter Validation
    assert all(c[a] >= 0 for a in range(m))
    assert all(f[a] >= 0 for a in range(m))
    assert all(d[k] > 0 for k in range(K))
    assert all(u[a] >= 0 for a in range(m))

    # Definitions
    out = [[] for _ in range(n)]
    for a in range(m):
        out[tail[a]].append(a)
    inc = [[] for _ in range(n)]
    for a in range(m):
        inc[head[a]].append(a)

    # Variables
    x = model.addVars(m, K, vtype=GRB.CONTINUOUS, name="x")
    y = model.addVars(m, vtype=GRB.INTEGER, name="y")

    # Constraints
    model.addConstrs(gp.quicksum(x[a, k] for a in out[O[k]]) == d[k] for k in range(K))
    model.addConstrs(gp.quicksum(x[a, k] for a in inc[D[k]]) == d[k] for k in range(K))
    model.addConstrs(
        gp.quicksum(x[a, k] for a in out[i]) - gp.quicksum(x[a, k] for a in inc[i]) == 0
        for k in range(K)
        for i in range(n)
        if i != O[k] and i != D[k]
    )
    model.addConstrs(
        gp.quicksum(x[a, k] for k in range(K)) <= u[a] * y[a] for a in range(m)
    )
    for k in range(K):
        inc_dk = inc[D[k]]
        if not inc_dk:
            continue
        u_max_k = max(u[a] for a in inc_dk)
        model.addConstr(
            gp.quicksum((u[a] + u_max_k) * y[a] for a in inc_dk) >= d[k] + u_max_k
        )

    # Implicit Constraints
    model.addConstrs(gp.quicksum(x[a, k] for a in out[D[k]]) == 0 for k in range(K))

    # Objective
    model.setObjective(
        gp.quicksum(c[a] * x[a, k] for a in range(m) for k in range(K))
        + gp.quicksum(f[a] * y[a] for a in range(m)),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(K)] for i in range(m)]
    variables["y"] = [y[i].x for i in range(m)]
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
