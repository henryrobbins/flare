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
    h1 = model.addVar(vtype=GRB.INTEGER, name="h1")
    h2 = model.addVar(vtype=GRB.INTEGER, name="h2")
    m1 = model.addVar(vtype=GRB.INTEGER, name="m1")
    m2 = model.addVar(vtype=GRB.INTEGER, name="m2")

    # Constraints
    model.addConstr(h1 + h2 <= S)
    model.addConstr((m1 + m2) * K + (h1 + h2) * D >= J)

    # Objective
    model.setObjective((m1 + m2) * M + (h1 + h2) * O, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h1"] = h1.x
    variables["h2"] = h2.x
    variables["m1"] = m1.x
    variables["m2"] = m2.x
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
