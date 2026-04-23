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
    L = data["L"]
    S = data["S"]
    P = data["P"]
    H = data["H"]
    T = data["T"]
    C = data["C"]
    D = data["D"]
    V = data["V"]

    # Parameter Validation
    assert L >= 0
    assert S >= 0
    assert P >= 0
    assert H >= 0
    assert T >= 0
    assert C >= 0
    assert D >= 0
    assert V >= 0

    # Variables
    h = model.addVar(vtype=GRB.CONTINUOUS, name="h")
    e = model.addVar(vtype=GRB.CONTINUOUS, name="e")

    # Constraints
    model.addConstr(C * e + P * h <= D, name="HeatingTime")
    model.addConstr(S * e + L * h <= V)

    # Implicit Constraints
    model.addConstr(e >= 0)
    model.addConstr(h >= 0)

    # Objective
    model.setObjective(45.0, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h"] = h.x
    variables["e"] = e.x
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
