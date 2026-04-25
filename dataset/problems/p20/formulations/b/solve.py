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
    nS = data["nS"]
    nT = data["nT"]
    nB = data["nB"]
    nP = data["nP"]
    nK = data["nK"]
    nL = data["nL"]
    S = data["S"]
    T = data["T"]
    B = data["B"]
    E = data["E"]
    pE = data["pE"]
    pRank = data["pRank"]
    c = data["c"]
    q = data["q"]
    nutval = data["nutval"]
    nutreq = data["nutreq"]
    dem = data["dem"]
    e = data["e"]

    # Parameter Validation
    assert nN >= 1
    assert nS >= 1
    assert nT >= 1
    assert nB >= 1
    assert nK >= 1
    assert nL >= 1
    assert all(0 <= S[s] < nN for s in range(nS))
    assert all(0 <= T[t] < nN for t in range(nT))
    assert all(0 <= B[j] < nN for j in range(nB))
    assert (
        set(S) | set(T) | set(B) == set(range(nN))
        and set(S).isdisjoint(T)
        and set(S).isdisjoint(B)
        and set(T).isdisjoint(B)
    )
    assert len(set(S)) == nS and len(set(T)) == nT and len(set(B)) == nB
    assert all(E[i][j] in (0, 1) for i in range(nN) for j in range(nN))
    assert all(e[j][p] in (0, 1) for j in range(nB) for p in range(nP))
    assert all(
        pE[p][i][j] in (0, 1) for p in range(nP) for i in range(nN) for j in range(nN)
    )
    assert all(
        pE[p][i][j] <= E[i][j] for p in range(nP) for i in range(nN) for j in range(nN)
    )
    assert all(
        sum(pE[p][i][v] for i in range(nN)) <= 1 for p in range(nP) for v in range(nN)
    )
    assert all(
        sum(pE[p][v][j] for j in range(nN)) <= 1 for p in range(nP) for v in range(nN)
    )
    for p in range(nP):
        sources = [
            v
            for v in range(nN)
            if sum(pE[p][v][j] for j in range(nN)) == 1
            and sum(pE[p][i][v] for i in range(nN)) == 0
        ]
        assert len(sources) == 1 and sources[0] in S
    for p in range(nP):
        sinks = [
            v
            for v in range(nN)
            if sum(pE[p][i][v] for i in range(nN)) == 1
            and sum(pE[p][v][j] for j in range(nN)) == 0
        ]
        assert len(sinks) == 1 and sinks[0] in B
    assert all(
        e[j][p]
        == sum(pE[p][i][B[j]] for i in range(nN))
        - sum(pE[p][B[j]][k] for k in range(nN))
        for j in range(nB)
        for p in range(nP)
    )
    assert all(
        pRank[p][j] == pRank[p][i] + 1
        for p in range(nP)
        for i in range(nN)
        for j in range(nN)
        if pE[p][i][j] == 1
    )
    # Completeness must be verified by external path enumeration; not asserted here.
    assert len({tuple(tuple(row) for row in pE[p]) for p in range(nP)}) == nP
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
