import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    F = data["F"]
    S = data["S"]
    R = data["R"]
    Z = data["Z"]
    W = data["W"]
    M = data["M"]

    # Parameter Validation
    assert F >= 0
    assert S >= 0
    assert R >= 0
    assert Z >= 0
    assert W >= 0
    assert M >= 0

    # Variables
    v = model.addVar(vtype=GRB.CONTINUOUS, name="v")
    n = model.addVar(vtype=GRB.CONTINUOUS, name="n")

    # Constraints
    model.addConstr(F * n + M * v <= R)
    model.addConstr(((100 - F) / 100) * n + ((100 - M) / 100) * v <= W)

    # Implicit Constraints
    model.addConstr(n >= 0)
    model.addConstr(v >= 0)

    # Objective
    model.setObjective(S * n + Z * v, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["v"] = v.x
    variables["n"] = n.x
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
