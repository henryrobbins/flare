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
    nS = data["nS"]
    nH = data["nH"]
    n = data["n"]
    T_limit = data["T_limit"]
    T = data["T"]
    delta = data["delta"]

    # Parameter Validation
    assert nS > 0
    assert nH > 0
    assert all(T[i][j] >= 0 for i in range(nS) for j in range(nH))
    assert T_limit >= 0
    assert n <= nS
    assert all(delta[i][j] in (0, 1) for i in range(nS) for j in range(nH))
    assert all(
        (delta[i][j] == 1) == (T[i][j] <= T_limit) for i in range(nS) for j in range(nH)
    )

    # Variables
    x = model.addVars(nS, vtype=GRB.BINARY, name="x")
    y = model.addVars(nS, nH, vtype=GRB.BINARY, name="y")

    # Constraints
    model.addConstr(gp.quicksum(x[i] for i in range(nS)) == n)
    model.addConstrs(
        gp.quicksum(delta[i][j] * y[i, j] for j in range(nH))
        <= x[i] * sum(delta[i][j] for j in range(nH))
        for i in range(nS)
    )
    model.addConstrs(
        gp.quicksum(delta[i][j] * y[i, j] for i in range(nS)) == 1 for j in range(nH)
    )
    model.addConstrs(
        y[i, j] == 0 for i in range(nS) for j in range(nH) if delta[i][j] == 0
    )

    # Objective
    model.setObjective(
        gp.quicksum(
            delta[i][j] * y[i, j] * T[i][j] for i in range(nS) for j in range(nH)
        ),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [x[i].x for i in range(nS)]
    variables["y"] = [[y[i, j].x for j in range(nH)] for i in range(nS)]
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
