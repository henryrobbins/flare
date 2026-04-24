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
    M = data["M"]
    nP = data["nP"]
    nS = data["nS"]
    v = data["v"]
    F = data["F"]
    U = data["U"]

    # Parameter Validation
    assert all(v[s][p] >= 0 for s in range(nS) for p in range(nP))
    assert all(
        F[s][h][p] in (0, 1) for s in range(nS) for h in range(M) for p in range(nP)
    )
    assert N <= M
    assert U >= 0
    assert nP > 0
    assert nS > 0
    assert M > 0

    # Variables
    y = model.addVars(M, vtype=GRB.BINARY, name="y")
    z = model.addVars(nS, nP, vtype=GRB.BINARY, name="z")

    # Constraints
    model.addConstr(gp.quicksum(y[h] for h in range(N, M)) <= U)
    model.addConstr(gp.quicksum(y[h] for h in range(N)) == N)
    model.addConstrs(
        z[s, p] <= gp.quicksum(F[s][h][p] * y[h] for h in range(M))
        for s in range(nS)
        for p in range(nP)
    )

    # Objective
    model.setObjective(
        gp.quicksum(v[s][p] * z[s, p] for s in range(nS) for p in range(nP)),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["y"] = [y[i].x for i in range(M)]
    variables["z"] = [[z[i, j].x for j in range(nP)] for i in range(nS)]
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
