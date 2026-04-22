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
    slack_0 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_0")
    slack_1 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_1")
    slack_2 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_2")

    # Constraints
    model.addConstr(A * s + K * r - slack_0 == U)
    model.addConstr(r + slack_1 == s)
    model.addConstr(s * Y + r * W + slack_2 == V)

    # Objective
    model.setObjective(s + r, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["r"] = r.x
    variables["s"] = s.x
    variables["slack_0"] = slack_0.x
    variables["slack_1"] = slack_1.x
    variables["slack_2"] = slack_2.x
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
