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
    U = data["U"]
    C = data["C"]
    V = data["V"]
    N = data["N"]
    Z = data["Z"]
    E = data["E"]
    P = data["P"]

    # Variables
    e = model.addVar(vtype=GRB.CONTINUOUS, name="e")
    p = model.addVar(vtype=GRB.CONTINUOUS, name="p")
    a = model.addVar(vtype=GRB.CONTINUOUS, name="a")

    # Constraints
    model.addConstr(p * Z <= P * (a * V + p * Z))
    model.addConstr(U * a + N * p <= C)
    model.addConstr(e >= E)

    # Objective
    model.setObjective(a * V + p * Z, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["e"] = e.x
    variables["p"] = p.x
    variables["a"] = a.x
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
