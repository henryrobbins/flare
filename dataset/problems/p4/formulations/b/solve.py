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
    J = data["J"]
    M = data["M"]
    K = data["K"]
    D = data["D"]
    O = data["O"]
    S = data["S"]

    # Parameter Validation
    assert J >= 0
    assert M >= 0
    assert K >= 0
    assert D >= 0
    assert O >= 0
    assert S >= 0

    # Variables
    h = model.addVar(vtype=GRB.INTEGER, name="h")
    m = model.addVar(vtype=GRB.INTEGER, name="m")

    # Constraints
    model.addConstr(h <= S)
    model.addConstr(m * K + h * D >= J)

    # Implicit Constraints
    model.addConstr(m >= 0)
    model.addConstr(h >= 0)

    # Objective
    model.setObjective(m * M + h * O, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h"] = h.x
    variables["m"] = m.x
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
