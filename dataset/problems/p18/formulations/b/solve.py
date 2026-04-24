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
    nI = data["nI"]
    m = data["m"]
    M = data["M"]
    v = data["v"]
    a = data["a"]
    p = data["p"]

    # Parameter Validation
    assert nI > 0
    assert M > 0
    assert all(v[i] >= 0 for i in range(nI))
    assert all(a[i][j] in (0, 1) for i in range(nI) for j in range(M))
    assert p >= 0
    assert m <= M

    # Variables
    x = model.addVars(M, vtype=GRB.BINARY, name="x")
    y = model.addVars(nI, M, vtype=GRB.BINARY, name="y")

    # Constraints
    model.addConstrs(x[j] == 1 for j in range(m))
    model.addConstr(gp.quicksum(x[j] for j in range(m, M)) <= p)
    model.addConstrs(
        gp.quicksum(y[i, j] for i in range(nI)) <= nI * x[j] for j in range(M)
    )
    model.addConstrs(gp.quicksum(y[i, j] for j in range(M)) <= 1 for i in range(nI))
    model.addConstrs(y[i, j] <= a[i][j] for i in range(nI) for j in range(M))

    # Objective
    model.setObjective(
        gp.quicksum(v[i] * y[i, j] for i in range(nI) for j in range(M)), GRB.MAXIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [x[i].x for i in range(M)]
    variables["y"] = [[y[i, j].x for j in range(M)] for i in range(nI)]
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
