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

    # Parameter Validation
    assert Y >= 0
    assert U >= 0
    assert A >= 0
    assert V >= 0
    assert K >= 0
    assert W >= 0

    # Variables
    r1 = model.addVar(vtype=GRB.INTEGER, name="r1")
    r2 = model.addVar(vtype=GRB.INTEGER, name="r2")
    s1 = model.addVar(vtype=GRB.INTEGER, name="s1")
    s2 = model.addVar(vtype=GRB.INTEGER, name="s2")

    # Constraints
    model.addConstr(A * (s1 + s2) + K * (r1 + r2) >= U)
    model.addConstr((r1 + r2) <= (s1 + s2))
    model.addConstr((s1 + s2) * Y + (r1 + r2) * W <= V)

    # Implicit Constraints
    model.addConstr(s1 >= 0)
    model.addConstr(s2 >= 0)
    model.addConstr(r1 >= 0)
    model.addConstr(r2 >= 0)

    # Objective
    model.setObjective((s1 + s2) + (r1 + r2), GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["r1"] = r1.x
    variables["r2"] = r2.x
    variables["s1"] = s1.x
    variables["s2"] = s2.x
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
