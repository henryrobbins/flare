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

    # Variables
    h = model.addVar(vtype=GRB.INTEGER, name="h")
    m = model.addVar(vtype=GRB.INTEGER, name="m")
    zed = model.addVar(vtype=GRB.CONTINUOUS, name="zed")

    # Constraints
    model.addConstr(zed == m * M + h * O)
    model.addConstr(h <= S)
    model.addConstr(m * K + h * D >= J)

    # Objective
    model.setObjective(zed, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h"] = h.x
    variables["m"] = m.x
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
