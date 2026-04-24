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
    nK = data["nK"]
    nV = data["nV"]
    nH = data["nH"]
    nI = data["nI"]
    nJ = data["nJ"]
    nA = data["nA"]
    cap = data["cap"]
    jApt = data["jApt"]
    pProfit = data["pProfit"]
    area = data["area"]
    m = data["m"]
    b = data["b"]
    s = data["s"]
    o = data["o"]
    iFree = data["iFree"]
    hCorp = data["hCorp"]

    # Parameter Validation
    assert nK > 0
    assert nV > 0
    assert nH > 0
    assert nI > 0
    assert nJ > 0
    assert nA > 0
    assert all(0 <= cap[v] <= nA for v in range(nV))
    assert all(0 <= jApt[v][a] < nJ for v in range(nV) for a in range(cap[v]))
    assert all(area[j] >= 0 for j in range(nJ))
    assert all(m[i][h] >= 0 for i in range(nI) for h in range(nH))
    assert all(b[i] >= 0 for i in range(nI))
    assert all(s[i] >= 0 for i in range(nI))
    assert all(o[h] >= 0 for h in range(nH))
    assert 0 <= iFree < nI
    assert 0 <= hCorp < nH

    # Variables
    x = model.addVars(nK, nV, nH, vtype=GRB.BINARY, name="x")
    y = model.addVars(
        [
            (k, v, h, i, a)
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for i in range(nI)
            for a in range(cap[v])
        ],
        vtype=GRB.BINARY,
        name="y",
    )

    # Constraints
    model.addConstrs(
        gp.quicksum(x[k, v, h] for v in range(nV) for h in range(nH)) == 1
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(y[k, v, h, i, a] for i in range(nI)) <= x[k, v, h]
        for k in range(nK)
        for v in range(nV)
        for h in range(nH)
        for a in range(cap[v])
    )
    model.addConstrs(
        gp.quicksum(
            y[k, v, h, i, a]
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for a in range(cap[v])
        )
        >= b[i]
        * gp.quicksum(
            y[k, v, h, ip, a]
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for ip in range(nI)
            for a in range(cap[v])
        )
        for i in range(nI)
    )
    model.addConstrs(
        gp.quicksum(
            area[jApt[v][a]] * y[k, v, h, i, a]
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for a in range(cap[v])
        )
        >= s[i]
        * gp.quicksum(
            y[k, v, h, i, a]
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for a in range(cap[v])
        )
        for i in range(nI)
    )
    model.addConstrs(
        y[k, v, h, i, a] == 0
        for k in range(nK)
        for v in range(nV)
        for h in range(nH)
        for i in range(nI)
        for a in range(cap[v])
        if area[jApt[v][a]] < m[i][h]
    )
    model.addConstrs(
        y[k, v, hCorp, iFree, a] == 0
        for k in range(nK)
        for v in range(nV)
        for a in range(cap[v])
    )
    model.addConstrs(
        gp.quicksum(x[k, v, h] * cap[v] for k in range(nK) for v in range(nV))
        >= o[h]
        * gp.quicksum(
            x[k, v, hp] * cap[v]
            for k in range(nK)
            for v in range(nV)
            for hp in range(nH)
        )
        for h in range(nH)
    )

    # Objective
    model.setObjective(
        gp.quicksum(
            pProfit[i][jApt[v][a]][h] * y[k, v, h, i, a]
            for k in range(nK)
            for v in range(nV)
            for h in range(nH)
            for i in range(nI)
            for a in range(cap[v])
        ),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["x"] = [
        [[x[i, j, k].x for k in range(nH)] for j in range(nV)] for i in range(nK)
    ]
    variables["y"] = {str(list(k)): y[k].x for k in y}
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
