import json
from gurobipy import Model, GRB, quicksum
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    N = data["N"]
    Y = data["Y"]
    A = data["A"]
    I = data["I"]
    M = data["M"]

    # Parameter Validation
    assert all(A[i] >= 0 for i in range(M))
    assert all(Y[j] >= 0 for j in range(N))
    assert all(I[j][i] >= 0 for j in range(N) for i in range(M))

    # Variables
    j = model.addVars(M, vtype=GRB.INTEGER, name="j")
    zed = model.addVar(vtype=GRB.CONTINUOUS, name="zed")

    # Constraints
    model.addConstr(zed == quicksum(j[i] * A[i] for i in range(M)))
    model.addConstrs(
        quicksum(I[k][i] * j[i] for i in range(M)) <= Y[k] for k in range(N)
    )

    # Implicit Constraints
    model.addConstrs(j[i] >= 0 for i in range(M))

    # Objective
    model.setObjective(zed, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["j"] = [j[i].x for i in range(M)]
    variables["zed"] = zed.x
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
