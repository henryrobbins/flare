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
    nK = data["nK"]
    nL = data["nL"]
    S = data["S"]
    T = data["T"]
    B = data["B"]
    E = data["E"]
    dem = data["dem"]
    pc = data["pc"]
    tc = data["tc"]
    nutreq = data["nutreq"]
    nutval = data["nutval"]

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
    assert all(dem[j] >= 0 for j in range(nB))
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
        gp.quicksum(E[i][S[s]] * F[i, S[s], k] for i in range(nN)) == 0
        for s in range(nS)
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(E[i][T[j]] * F[i, T[j], k] for i in range(nN))
        == gp.quicksum(E[T[j]][i] * F[T[j], i, k] for i in range(nN))
        for j in range(nT)
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(E[B[b]][j] * F[B[b], j, k] for j in range(nN)) == 0
        for b in range(nB)
        for k in range(nK)
    )
    model.addConstrs(
        gp.quicksum(E[i][B[j]] * F[i, B[j], k] for i in range(nN)) >= dem[j] * R[k]
        for j in range(nB)
        for k in range(nK)
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
            pc[k]
            * gp.quicksum(
                E[S[s]][j] * F[S[s], j, k] for s in range(nS) for j in range(nN)
            )
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
