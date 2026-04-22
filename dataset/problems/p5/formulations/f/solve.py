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
    P = data["P"]
    B = data["B"]
    D = data["D"]
    Z = data["Z"]
    K = data["K"]

    # Variables
    d1 = model.addVar(vtype=GRB.INTEGER, name="d1")
    d2 = model.addVar(vtype=GRB.INTEGER, name="d2")
    h1 = model.addVar(vtype=GRB.INTEGER, name="h1")
    h2 = model.addVar(vtype=GRB.INTEGER, name="h2")

    # Constraints
    model.addConstr((d1 + d2) <= K * ((d1 + d2) + (h1 + h2)))
    model.addConstr((h1 + h2) + (d1 + d2) <= D)
    model.addConstr((d1 + d2) >= P)

    # Objective
    model.setObjective(Z * (h1 + h2) + B * (d1 + d2), GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["d1"] = d1.x
    variables["d2"] = d2.x
    variables["h1"] = h1.x
    variables["h2"] = h2.x
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
