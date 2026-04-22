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
    s_0 = model.addVar(vtype=GRB.INTEGER, name="s_0")
    s_1 = model.addVar(vtype=GRB.INTEGER, name="s_1")
    r_0 = model.addVar(vtype=GRB.INTEGER, name="r_0")
    r_1 = model.addVar(vtype=GRB.INTEGER, name="r_1")

    # Constraints
    model.addConstr(
        A * (s_0 * 10**0 + s_1 * 10**1) + K * (r_0 * 10**0 + r_1 * 10**1) >= U
    )
    model.addConstr((r_0 * 10**0 + r_1 * 10**1) <= (s_0 * 10**0 + s_1 * 10**1))
    model.addConstr(
        (s_0 * 10**0 + s_1 * 10**1) * Y + (r_0 * 10**0 + r_1 * 10**1) * W <= V
    )

    # Objective
    model.setObjective(
        (s_0 * 10**0 + s_1 * 10**1) + (r_0 * 10**0 + r_1 * 10**1), GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["s_0"] = s_0.x
    variables["s_1"] = s_1.x
    variables["r_0"] = r_0.x
    variables["r_1"] = r_1.x
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
