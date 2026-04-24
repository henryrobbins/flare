import json
import gurobipy as gp
from gurobipy import GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = gp.Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    nP = data["nP"]
    nA = data["nA"]
    nT = data["nT"]
    tau = data["tau"]
    r = data["r"]
    cap = data["cap"]

    # Parameter Validation
    assert all(cap[a][t] >= 0 for a in range(nA) for t in range(nT))

    # Variables
    y = model.addVars(nP, nA, nT, vtype=GRB.BINARY, name="y")
    z = model.addVars(nP, nA, nA, nT, vtype=GRB.BINARY, name="z")

    # Constraints
    model.addConstrs(
        gp.quicksum(y[p, a, t] for a in range(nA)) == 1
        for p in range(nP)
        for t in range(nT)
    )
    model.addConstrs(
        gp.quicksum(y[p, a, t] for p in range(nP)) <= cap[a][t]
        for a in range(nA)
        for t in range(nT)
    )
    model.addConstrs(
        y[p, a, t]
        == y[p, a, t - 1]
        + gp.quicksum(
            z[p, a2, a, t2]
            for a2 in range(nA)
            for t2 in range(nT)
            if t2 + tau[a2][a] == t
        )
        - gp.quicksum(z[p, a, a2, t] for a2 in range(nA))
        for p in range(nP)
        for a in range(nA)
        for t in range(1, nT)
    )

    # Objective
    model.setObjective(
        gp.quicksum(
            r[a][t] * y[p, a, t]
            for p in range(nP)
            for a in range(nA)
            for t in range(nT)
        ),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["y"] = [
        [[y[i, j, k].x for k in range(nT)] for j in range(nA)] for i in range(nP)
    ]
    variables["z"] = [
        [[[z[i, j, k, l].x for l in range(nT)] for k in range(nA)] for j in range(nA)]
        for i in range(nP)
    ]
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
