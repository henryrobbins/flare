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
    N = data["N"]

    # Parameter Validation
    assert N >= 1

    # Definitions
    R = range(N)
    C = range(N)
    I = [(a, b) for a in C for b in range(a, N)]

    # Variables
    h = model.addVars(N, N, vtype=GRB.BINARY, name="h")
    x = model.addVars(
        [(i, a, b) for i in R for (a, b) in I], vtype=GRB.BINARY, name="x"
    )
    s = model.addVars(
        [(i, a, b) for i in R for (a, b) in I], vtype=GRB.BINARY, name="s"
    )
    t = model.addVars(
        [(i, a, b) for i in R for (a, b) in I], vtype=GRB.BINARY, name="t"
    )

    # Constraints
    model.addConstrs(gp.quicksum(h[i, j] for j in C) == 1 for i in R)
    model.addConstrs(gp.quicksum(h[i, j] for i in R) == 1 for j in C)
    model.addConstrs(
        gp.quicksum(x[i, a, b] for (a, b) in I if a <= j <= b) + h[i, j] == 1
        for i in R
        for j in C
    )
    model.addConstrs(x[0, a, b] - s[0, a, b] == 0 for (a, b) in I)
    model.addConstrs(
        x[i, a, b] - x[i - 1, a, b] - s[i, a, b] + t[i - 1, a, b] == 0
        for i in range(1, N)
        for (a, b) in I
    )
    model.addConstrs(x[N - 1, a, b] - t[N - 1, a, b] == 0 for (a, b) in I)
    model.addConstrs(
        h[i, j] <= gp.quicksum(t[i, a, b] for (a, b) in I if b == j - 1)
        for i in R
        for j in range(1, N)
    )

    # Objective
    model.setObjective(gp.quicksum(s[i, a, b] for i in R for (a, b) in I), GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h"] = [[h[i, j].x for j in range(N)] for i in range(N)]
    variables["x"] = {str(list(k)): x[k].x for k in x}
    variables["s"] = {str(list(k)): s[k].x for k in s}
    variables["t"] = {str(list(k)): t[k].x for k in t}
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
