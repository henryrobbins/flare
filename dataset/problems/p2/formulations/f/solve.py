import json
from gurobipy import Model, GRB, quicksum
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    N = data["N"]
    Y = data["Y"]
    A = data["A"]
    I = data["I"]
    M = data["M"]

    # Variables
    j1 = model.addVars(M, vtype=GRB.INTEGER, name="j1")
    j2 = model.addVars(M, vtype=GRB.INTEGER, name="j2")

    # Constraints
    model.addConstrs(
        quicksum(I[k][i] * (j1[i] + j2[i]) for i in range(M)) <= Y[k] for k in range(N)
    )

    # Objective
    model.setObjective(quicksum((j1[i] + j2[i]) * A[i] for i in range(M)), GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["j1"] = [j1[i].x for i in range(M)]
    variables["j2"] = [j2[i].x for i in range(M)]
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
