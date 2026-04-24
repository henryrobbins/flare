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
    nK = data["nK"]
    nL = data["nL"]
    nB = data["nB"]
    c = data["c"]
    q = data["q"]
    nutval = data["nutval"]
    nutreq = data["nutreq"]
    dem = data["dem"]
    e = data["e"]

    # Parameter Validation
    assert all(c[p][k] >= 0 for p in range(nP) for k in range(nK))
    assert all(q[k] >= 0 for k in range(nK))
    assert all(nutval[k][l] >= 0 for k in range(nK) for l in range(nL))
    assert all(nutreq[l] >= 0 for l in range(nL))
    assert all(dem[j] >= 0 for j in range(nB))

    # Variables
    x = model.addVars(nP, nK, vtype=GRB.CONTINUOUS, name="x")
    R = model.addVars(nK, vtype=GRB.CONTINUOUS, name="R")

    # Constraints
    model.addConstrs(
        gp.quicksum(e[j][p] * x[p, k] for p in range(nP)) >= dem[j] * R[k]
        for j in range(nB)
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(nutval[k][l] * R[k] for k in range(nK)) >= nutreq[l]
        for l in range(nL)
    )

    # Implicit Constraints
    model.addConstrs(x[p, k] >= 0 for p in range(nP) for k in range(nK))
    model.addConstrs(R[k] >= 0 for k in range(nK))

    # Objective
    model.setObjective(
        gp.quicksum(c[p][k] * x[p, k] for p in range(nP) for k in range(nK))
        + gp.quicksum(
            q[k] * gp.quicksum(x[p, k] for p in range(nP)) for k in range(nK)
        ),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(nK)] for i in range(nP)]
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
