import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:
    model = Model()

    with open(params_path, "r") as f:
        data = json.load(f)
    N = data["N"]
    D = data["D"]
    Z = data["Z"]
    E = data["E"]
    T = data["T"]
    V = data["V"]
    X = data["X"]
    C = data["C"]
    n = model.addVars(N, vtype=GRB.CONTINUOUS, name="n")
    model.addConstr(quicksum(n[i] for i in range(N)) <= D)
    model.addConstr(quicksum(V[i] * n[i] for i in range(N)) <= Z)
    model.addConstr(quicksum(C[i] * n[i] for i in range(N)) <= E)
    model.setObjective(quicksum(X[i] * n[i] for i in range(N)), GRB.MAXIMIZE)
    model.optimize()
    solution = {}
    variables = {}

    objective = []
    variables["n"] = {i: n[i].X for i in range(N)}
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
