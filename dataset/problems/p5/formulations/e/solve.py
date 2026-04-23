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

    # Parameter Validation
    assert P >= 0
    assert B >= 0
    assert D >= 0
    assert Z >= 0
    assert K >= 0

    # Variables
    d = model.addVar(vtype=GRB.INTEGER, name="d")
    h = model.addVar(vtype=GRB.INTEGER, name="h")
    slack_0 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_0")
    slack_1 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_1")
    slack_2 = model.addVar(vtype=GRB.CONTINUOUS, name="slack_2")

    # Constraints
    model.addConstr(d + slack_0 == K * (d + h))
    model.addConstr(h + d + slack_1 == D)
    model.addConstr(d - slack_2 == P)
    model.addConstr(h >= 0)
    model.addConstr(d >= 0)

    # Implicit Constraints
    model.addConstr(slack_0 >= 0)
    model.addConstr(slack_1 >= 0)
    model.addConstr(slack_2 >= 0)

    # Objective
    model.setObjective(Z * h + B * d, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["d"] = d.x
    variables["h"] = h.x
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
