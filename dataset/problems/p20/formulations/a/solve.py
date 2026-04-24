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
    nN = data["nN"]
    nK = data["nK"]
    nL = data["nL"]
    isB = data["isB"]
    E = data["E"]
    dem = data["dem"]
    pc = data["pc"]
    tc = data["tc"]
    nutreq = data["nutreq"]
    nutval = data["nutval"]

    # Parameter Validation
    assert all(dem[j] >= 0 for j in range(nN))
    assert all(pc[k] >= 0 for k in range(nK))
    assert all(
        tc[i][j][k] >= 0 for i in range(nN) for j in range(nN) for k in range(nK)
    )
    assert all(nutreq[l] >= 0 for l in range(nL))
    assert all(nutval[k][l] >= 0 for k in range(nK) for l in range(nL))

    # Variables
    F = model.addVars(nN, nN, nK, vtype=GRB.CONTINUOUS, name="F")
    R = model.addVars(nK, vtype=GRB.CONTINUOUS, name="R")

    # Constraints
    model.addConstrs(
        gp.quicksum(E[i][j] * F[i, j, k] for i in range(nN))
        == gp.quicksum(E[j][i] * F[j, i, k] for i in range(nN))
        for j in range(nN)
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(E[i][j] * F[i, j, k] for i in range(nN)) >= dem[j] * R[k]
        for j in range(nN)
        for k in range(nK)
        if isB[j] == 1
    )
    model.addConstrs(
        gp.quicksum(nutval[k][l] * R[k] for k in range(nK)) >= nutreq[l]
        for l in range(nL)
    )

    # Implicit Constraints
    model.addConstrs(
        F[i, j, k] >= 0 for i in range(nN) for j in range(nN) for k in range(nK)
    )
    model.addConstrs(R[k] >= 0 for k in range(nK))

    # Objective
    model.setObjective(
        gp.quicksum(
            pc[k] * gp.quicksum(isB[j] * dem[j] * R[k] for j in range(nN))
            for k in range(nK)
        )
        + gp.quicksum(
            tc[i][j][k] * F[i, j, k]
            for i in range(nN)
            for j in range(nN)
            for k in range(nK)
        ),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["F"] = [
        [[F[i, j, k].x for k in range(nK)] for j in range(nN)] for i in range(nN)
    ]
    variables["R"] = [R[i].x for i in range(nK)]
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
