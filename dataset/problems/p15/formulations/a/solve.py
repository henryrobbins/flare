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
    nI = data["nI"]
    nJ = data["nJ"]
    nH = data["nH"]
    nV = data["nV"]
    K = data["K"]
    R = data["R"]
    O = data["O"]
    area = data["area"]
    m = data["m"]
    a = data["a"]
    s = data["s"]
    o = data["o"]
    iFree = data["iFree"]
    hCorp = data["hCorp"]

    # Parameter Validation
    assert nI > 0
    assert nJ > 0
    assert nH > 0
    assert nV > 0
    assert all(R[j][v] >= 0 for j in range(nJ) for v in range(nV))
    assert all(area[j] >= 0 for j in range(nJ))
    assert all(m[i][h] >= 0 for i in range(nI) for h in range(nH))
    assert all(a[i] >= 0 for i in range(nI))
    assert all(s[i] >= 0 for i in range(nI))
    assert all(o[h] >= 0 for h in range(nH))
    assert 0 <= iFree < nI
    assert 0 <= hCorp < nH

    # Variables
    x = model.addVars(nV, nH, vtype=GRB.INTEGER, name="x")
    y = model.addVars(nI, nJ, nH, vtype=GRB.INTEGER, name="y")

    # Constraints
    model.addConstr(gp.quicksum(x[v, h] for v in range(nV) for h in range(nH)) == K)
    model.addConstrs(
        gp.quicksum(R[j][v] * x[v, h] for v in range(nV))
        == gp.quicksum(y[i, j, h] for i in range(nI))
        for j in range(nJ)
        for h in range(nH)
    )
    model.addConstrs(
        gp.quicksum(y[i, j, h] for j in range(nJ) for h in range(nH))
        >= a[i]
        * gp.quicksum(
            y[l, j, h] for l in range(nI) for j in range(nJ) for h in range(nH)
        )
        for i in range(nI)
    )
    model.addConstrs(
        gp.quicksum(area[j] * y[i, j, h] for j in range(nJ) for h in range(nH))
        >= s[i] * gp.quicksum(y[i, j, h] for j in range(nJ) for h in range(nH))
        for i in range(nI)
    )
    model.addConstrs(
        y[i, j, h] == 0
        for i in range(nI)
        for j in range(nJ)
        for h in range(nH)
        if area[j] < m[i][h]
    )
    model.addConstrs(y[iFree, j, hCorp] == 0 for j in range(nJ))
    model.addConstrs(
        gp.quicksum(y[i, j, h] for i in range(nI) for j in range(nJ))
        >= o[h]
        * gp.quicksum(
            y[i, j, hp] for i in range(nI) for j in range(nJ) for hp in range(nH)
        )
        for h in range(nH)
    )

    # Implicit Constraints
    model.addConstrs(x[v, h] >= 0 for v in range(nV) for h in range(nH))
    model.addConstrs(
        y[i, j, h] >= 0 for i in range(nI) for j in range(nJ) for h in range(nH)
    )

    # Objective
    model.setObjective(
        gp.quicksum(
            O[i][j][h] * y[i, j, h]
            for i in range(nI)
            for j in range(nJ)
            for h in range(nH)
        ),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [[x[i, j].x for j in range(nH)] for i in range(nV)]
    variables["y"] = [
        [[y[i, j, k].x for k in range(nH)] for j in range(nJ)] for i in range(nI)
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
