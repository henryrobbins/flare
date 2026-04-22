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
    Q = data["Q"]
    D = data["D"]
    O = data["O"]
    J = data["J"]
    A = data["A"]

    # Variables
    z = model.addVar(vtype=GRB.CONTINUOUS, name="z")
    g = model.addVar(vtype=GRB.CONTINUOUS, name="g")

    # Constraints
    model.addConstr(z >= O * g)
    model.addConstr(g >= Q)
    model.addConstr(D * g + J * z <= A)

    # Objective
    model.setObjective(g + z, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["z"] = z.x
    variables["g"] = g.x
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
