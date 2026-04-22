import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:
    model = Model()

    with open(params_path, "r") as f:
        data = json.load(f)
    M = data["M"]
    N = data["N"]
    Y = data["Y"]
    I = data["I"]
    A = data["A"]
    j = model.addVars(M, vtype=GRB.CONTINUOUS, name="j")
    model.addConstr(quicksum(I[0][i] * j[i] for i in range(M)) <= Y[0])
    model.addConstr(quicksum(I[1][i] * j[i] for i in range(M)) <= Y[1])
    model.setObjective(quicksum(j[i] * A[i] for i in range(M)), GRB.MAXIMIZE)
    model.optimize()
    solution = {}
    variables = {}

    objective = []
    variables["j"] = {i: j[i].X for i in range(M)}
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
