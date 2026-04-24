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

    # Variables
    h = model.addVars(N, N, vtype=GRB.BINARY, name="h")
    x = model.addVars(N, N, N, vtype=GRB.BINARY, name="x")
    s = model.addVars(N, N, N, vtype=GRB.BINARY, name="s")
    t = model.addVars(N, N, N, vtype=GRB.BINARY, name="t")

    # Constraints
    model.addConstrs(gp.quicksum(h[i, j] for j in range(N)) == 1 for i in range(N))
    model.addConstrs(gp.quicksum(h[i, j] for i in range(N)) == 1 for j in range(N))
    model.addConstrs(
        gp.quicksum(
            x[i, a, b]
            for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
            if a <= j <= b
        )
        + h[i, j]
        == 1
        for i in range(N)
        for j in range(N)
    )
    model.addConstrs(
        x[0, a, b] - s[0, a, b] == 0
        for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
    )
    model.addConstrs(
        x[i, a, b] - x[i - 1, a, b] - s[i, a, b] + t[i - 1, a, b] == 0
        for i in range(1, N)
        for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
    )
    model.addConstrs(
        x[N - 1, a, b] - t[N - 1, a, b] == 0
        for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
    )
    model.addConstrs(
        gp.quicksum(
            s[i, a, b]
            for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
            if a <= j <= b
        )
        >= h[i - 1, j] - h[i, j]
        for i in range(1, N)
        for j in range(N)
    )

    # Objective
    model.setObjective(
        gp.quicksum(
            s[i, a, b]
            for i in range(N)
            for (a, b) in [(a, b) for a in range(N) for b in range(a, N)]
        ),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h"] = [[h[i, j].x for j in range(N)] for i in range(N)]
    variables["x"] = [
        [[x[i, j, k].x for k in range(N)] for j in range(N)] for i in range(N)
    ]
    variables["s"] = [
        [[s[i, j, k].x for k in range(N)] for j in range(N)] for i in range(N)
    ]
    variables["t"] = [
        [[t[i, j, k].x for k in range(N)] for j in range(N)] for i in range(N)
    ]
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
