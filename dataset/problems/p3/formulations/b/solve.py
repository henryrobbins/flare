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
    C = data["C"]
    E = data["E"]
    N = data["N"]
    X = data["X"]
    T = data["T"]
    D = data["D"]
    V = data["V"]
    Z = data["Z"]

    # Parameter Validation
    assert N >= 1
    assert all(C[i] >= 0 for i in range(N))
    assert all(X[i] >= 0 for i in range(N))
    assert all(T[i] >= 0 for i in range(N))
    assert all(V[i] >= 0 for i in range(N))

    # Variables
    n = model.addVars(N, vtype=GRB.INTEGER, name="n")

    # Constraints
    model.addConstr(quicksum(V[i] * n[i] for i in range(N)) <= Z)
    model.addConstr(quicksum(T[i] * n[i] for i in range(N)) <= D)
    model.addConstr(quicksum(C[i] * n[i] for i in range(N)) <= E)

    # Implicit Constraints
    model.addConstrs(n[i] >= 0 for i in range(N))

    # Objective
    model.setObjective(quicksum(X[i] * n[i] for i in range(N)), GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["n"] = [n[i].x for i in range(N)]
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
