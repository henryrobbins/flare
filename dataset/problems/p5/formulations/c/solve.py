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
    h_0 = model.addVar(vtype=GRB.INTEGER, name="h_0")
    h_1 = model.addVar(vtype=GRB.INTEGER, name="h_1")
    d_0 = model.addVar(vtype=GRB.INTEGER, name="d_0")
    d_1 = model.addVar(vtype=GRB.INTEGER, name="d_1")

    # Constraints
    model.addConstr(
        (d_0 * 10**0 + d_1 * 10**1)
        <= K * ((d_0 * 10**0 + d_1 * 10**1) + (h_0 * 10**0 + h_1 * 10**1))
    )
    model.addConstr((h_0 * 10**0 + h_1 * 10**1) + (d_0 * 10**0 + d_1 * 10**1) <= D)
    model.addConstr((d_0 * 10**0 + d_1 * 10**1) >= P)

    # Objective
    model.setObjective(
        Z * (h_0 * 10**0 + h_1 * 10**1) + B * (d_0 * 10**0 + d_1 * 10**1), GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["h_0"] = h_0.x
    variables["h_1"] = h_1.x
    variables["d_0"] = d_0.x
    variables["d_1"] = d_1.x
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
