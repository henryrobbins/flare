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
    t = data["t"]
    c = data["c"]
    g = data["g"]
    O = data["O"]
    W = data["W"]
    G_min = data["G_min"]
    G_max = data["G_max"]
    PC_min = data["PC_min"]
    PC_max = data["PC_max"]
    MC_min = data["MC_min"]
    MC_max = data["MC_max"]
    P = data["P"]

    # Parameter Validation
    assert all(O[i] >= 0 for i in range(n))
    assert all(W[i] >= 0 for i in range(n))
    assert all(P[i][j] in (0, 1) for i in range(n) for j in range(n))
    assert n >= 1
    assert t >= 1

    # Variables
    x = model.addVars(n, t, vtype=GRB.BINARY, name="x")

    # Constraints
    model.addConstrs(
        gp.quicksum((g[i] - G_max) * O[i] * x[i, tau] for i in range(n)) <= 0
        for tau in range(t)
    )
    model.addConstrs(
        gp.quicksum((g[i] - G_min) * O[i] * x[i, tau] for i in range(n)) >= 0
        for tau in range(t)
    )
    model.addConstrs(gp.quicksum(x[i, tau] for tau in range(t)) <= 1 for i in range(n))
    model.addConstrs(
        gp.quicksum(O[i] * x[i, tau] for i in range(n)) <= PC_max for tau in range(t)
    )
    model.addConstrs(
        gp.quicksum(O[i] * x[i, tau] for i in range(n)) >= PC_min for tau in range(t)
    )
    model.addConstrs(
        gp.quicksum((O[i] + W[i]) * x[i, tau] for i in range(n)) <= MC_max
        for tau in range(t)
    )
    model.addConstrs(
        gp.quicksum((O[i] + W[i]) * x[i, tau] for i in range(n)) >= MC_min
        for tau in range(t)
    )
    model.addConstrs(
        gp.quicksum(x[i, tau2] for tau2 in range(tau + 1)) >= x[j, tau]
        for tau in range(t)
        for i in range(n)
        for j in range(n)
        if P[i][j] == 1
    )

    # Objective
    model.setObjective(
        gp.quicksum(c[i][tau] * x[i, tau] for i in range(n) for tau in range(t)),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(t)] for i in range(n)]
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
