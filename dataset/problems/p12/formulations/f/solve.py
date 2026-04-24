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
    c = data["c"]

    # Variables
    x = model.addVars(n, n, vtype=GRB.BINARY, name="x")
    u = model.addVars(n, vtype=GRB.CONTINUOUS, name="u")

    # Constraints
    model.addConstrs(
        gp.quicksum(x[i, j] for j in range(n) if j != i) == 1 for i in range(n)
    )
    model.addConstrs(
        gp.quicksum(x[i, j] for i in range(n) if i != j) == 1 for j in range(n)
    )
    model.addConstrs(
        u[i] - u[j] + n * x[i, j] <= n - 1
        for i in range(1, n)
        for j in range(1, n)
        if i != j
    )
    model.addConstr(u[0] == 1)
    model.addConstrs(u[i] >= 2 for i in range(1, n))
    model.addConstrs(u[i] <= n - 1 for i in range(1, n))
    model.addConstrs(
        x[0, i] + x[i, 0] + x[0, j] + x[j, 0] + x[i, j] + x[j, i] <= 2
        for i in range(1, n)
        for j in range(i + 1, n)
    )

    # Implicit Constraints
    model.addConstrs(x[i, i] == 0 for i in range(n))

    # Objective
    model.setObjective(
        gp.quicksum(c[i][j] * x[i, j] for i in range(n) for j in range(n) if i != j),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(n)] for i in range(n)]
    variables["u"] = [u[i].x for i in range(n)]
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
