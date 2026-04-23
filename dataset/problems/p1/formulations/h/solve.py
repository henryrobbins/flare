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
    V = data["V"]
    G = data["G"]
    Y = data["Y"]
    K = data["K"]

    # Parameter Validation
    assert L >= 0
    assert V >= 0
    assert G >= 0
    assert Y >= 0
    assert K >= 0

    # Variables
    c = model.addVar(vtype=GRB.INTEGER, name="c")
    p = model.addVar(vtype=GRB.INTEGER, name="p")

    # Constraints
    model.addConstr(p <= K * c)
    model.addConstr(c >= L)
    model.addConstr(G * c + Y * p >= V)

    # Implicit Constraints
    model.addConstr(c >= 0)
    model.addConstr(p >= 0)

    # Objective
    model.setObjective(c + p, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["c"] = c.x
    variables["p"] = p.x
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
