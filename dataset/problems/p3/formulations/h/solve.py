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

    # Variables
    h = model.addVar(vtype=GRB.CONTINUOUS, name="h")
    e = model.addVar(vtype=GRB.CONTINUOUS, name="e")

    # Constraints
    model.addConstr(C * e + P * h <= D, name="HeatingTime")
    model.addConstr(S * e + L * h <= V)

    # Objective
    model.setObjective(T * e + H * h, GRB.MAXIMIZE)

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
