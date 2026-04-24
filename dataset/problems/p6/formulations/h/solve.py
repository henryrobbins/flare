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
    d = data["d"]
    u = data["u"]
    f = data["f"]
    c = data["c"]

    # Parameter Validation
    assert all(d[i] > 0 for i in range(n))
    assert all(u[j] >= 0 for j in range(m))
    assert all(c[i][j] >= 0 for i in range(n) for j in range(m))
    assert all(f[j] >= 0 for j in range(m))

    # Variables
    x = model.addVars(n, m, vtype=GRB.BINARY, name="x")
    y = model.addVars(m, vtype=GRB.BINARY, name="y")

    # Constraints
    model.addConstrs(gp.quicksum(x[i, j] for j in range(m)) == 1 for i in range(n))
    model.addConstrs(
        gp.quicksum(d[i] * x[i, j] for i in range(n)) <= u[j] * y[j] for j in range(m)
    )
    for i in range(n):
        for j in range(m):
            if d[i] > u[j]:
                x[i, j].ub = 0

    # Objective
    model.setObjective(
        gp.quicksum(f[j] * y[j] for j in range(m))
        + gp.quicksum(c[i][j] * x[i, j] for i in range(n) for j in range(m)),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(m)] for i in range(n)]
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
