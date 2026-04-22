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
    Y = data["Y"]
    U = data["U"]
    A = data["A"]
    V = data["V"]
    K = data["K"]
    W = data["W"]

    # Variables
    r = model.addVar(vtype=GRB.INTEGER, name="r")
    s = model.addVar(vtype=GRB.INTEGER, name="s")

    # Constraints
    model.addConstr(A * s + K * r >= U)
    model.addConstr(r <= s)
    model.addConstr(s * Y + r * W <= V)

    # Objective
    model.setObjective(s + r, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["r"] = r.x
    variables["s"] = s.x
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
