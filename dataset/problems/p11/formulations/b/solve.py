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
    T = data["T"]
    n_G = data["n_G"]
    n_W = data["n_W"]
    n_S = data["n_S"]
    ell = data["ell"]
    C_su = data["C_su"]
    n_L = data["n_L"]
    P = data["P"]
    C = data["C"]
    C_fixed = data["C_fixed"]
    L = data["L"]
    R = data["R"]
    P_min = data["P_min"]
    P_max = data["P_max"]
    P_wind_min = data["P_wind_min"]
    P_wind_max = data["P_wind_max"]
    RU = data["RU"]
    RD = data["RD"]
    SU = data["SU"]
    SD = data["SD"]
    U = data["U"]
    D = data["D"]
    MR = data["MR"]

    # Parameter Validation
    assert T >= 1
    assert n_G >= 1
    assert n_W >= 1
    assert all(n_S[g] >= 1 for g in range(n_G))
    assert all(n_L[g] >= 1 for g in range(n_G))
    assert all(ell[g][s] >= 0 for g in range(n_G) for s in range(n_S[g]))
    assert all(C_su[g][s] >= 0 for g in range(n_G) for s in range(n_S[g]))
    assert all(P[g][l] >= 0 for g in range(n_G) for l in range(n_L[g]))
    assert all(C[g][l] >= 0 for g in range(n_G) for l in range(n_L[g]))
    assert all(C_fixed[g] >= 0 for g in range(n_G))
    assert all(L[t] >= 0 for t in range(T))
    assert all(R[t] >= 0 for t in range(T))
    assert all(P_min[g] >= 0 for g in range(n_G))
    assert all(P_max[g] >= 0 for g in range(n_G))
    assert all(P_wind_min[w][t] >= 0 for w in range(n_W) for t in range(T))
    assert all(P_wind_max[w][t] >= 0 for w in range(n_W) for t in range(T))
    assert all(RU[g] >= 0 for g in range(n_G))
    assert all(RD[g] >= 0 for g in range(n_G))
    assert all(SU[g] >= 0 for g in range(n_G))
    assert all(SD[g] >= 0 for g in range(n_G))
    assert all(U[g] >= 1 for g in range(n_G))
    assert all(D[g] >= 1 for g in range(n_G))
    assert all(MR[g] >= 0 for g in range(n_G))
    assert all(P_max[g] >= P_min[g] for g in range(n_G))
    assert all(
        P_wind_max[w][t] >= P_wind_min[w][t] for w in range(n_W) for t in range(T)
    )

    # Variables
    u = model.addVars(n_G, T, vtype=GRB.BINARY, name="u")
    v = model.addVars(n_G, T, vtype=GRB.BINARY, name="v")
    w = model.addVars(n_G, T, vtype=GRB.BINARY, name="w")
    d_su = {
        (g, s, t): model.addVar(vtype=GRB.BINARY, name=f"d_su_{g}_{s}_{t}")
        for g in range(n_G)
        for s in range(n_S[g])
        for t in range(T)
    }
    lam = {
        (g, l, t): model.addVar(vtype=GRB.CONTINUOUS, name=f"lam_{g}_{l}_{t}")
        for g in range(n_G)
        for l in range(n_L[g])
        for t in range(T)
    }
    p = model.addVars(n_G, T, vtype=GRB.CONTINUOUS, name="p")
    r = model.addVars(n_G, T, vtype=GRB.CONTINUOUS, name="r")
    c_var = model.addVars(n_G, T, vtype=GRB.CONTINUOUS, name="c_var")
    b = model.addVars(n_G, T - 1, vtype=GRB.BINARY, name="b")

    # Constraints
    for t in range(T):
        model.addConstr(
            gp.quicksum(p[g, t] + P_min[g] * u[g, t] for g in range(n_G)) == L[t]
        )
    model.addConstrs(gp.quicksum(r[g, t] for g in range(n_G)) >= R[t] for t in range(T))
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(u[g, t] - u[g, t - 1] == v[g, t] - w[g, t])
    for g in range(n_G):
        for t in range(U[g] - 1, T):
            model.addConstr(
                gp.quicksum(v[g, tau] for tau in range(t - U[g] + 1, t + 1)) <= u[g, t]
            )
    for g in range(n_G):
        for t in range(D[g] - 1, T):
            model.addConstr(
                gp.quicksum(w[g, tau] for tau in range(t - D[g] + 1, t + 1))
                <= 1 - u[g, t]
            )
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                v[g, t] == gp.quicksum(d_su[g, s, t] for s in range(n_S[g]))
            )
    for g in range(n_G):
        for s in range(n_S[g] - 1):
            for t in range(ell[g][s + 1] - 1, T):
                model.addConstr(
                    d_su[g, s, t]
                    <= gp.quicksum(w[g, t - i] for i in range(ell[g][s], ell[g][s + 1]))
                )
    for g in range(n_G):
        if MR[g] > 0:
            for t in range(T):
                model.addConstr(u[g, t] >= MR[g])
    for g in range(n_G):
        su_derate = max(P_max[g] - SU[g], 0)
        for t in range(T):
            model.addConstr(
                p[g, t] + r[g, t]
                <= (P_max[g] - P_min[g]) * u[g, t] - su_derate * v[g, t]
            )
    for g in range(n_G):
        sd_derate = max(P_max[g] - SD[g], 0)
        for t in range(T - 1):
            model.addConstr(
                p[g, t] + r[g, t]
                <= (P_max[g] - P_min[g]) * u[g, t] - sd_derate * w[g, t + 1]
            )
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t] + r[g, t] - p[g, t - 1] <= RU[g])
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t - 1] - p[g, t] <= RD[g])
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                p[g, t]
                == gp.quicksum(
                    (P[g][l] - P[g][0]) * lam[g, l, t] for l in range(n_L[g])
                )
            )
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                c_var[g, t]
                == gp.quicksum(
                    (C[g][l] - C_fixed[g]) * lam[g, l, t] for l in range(n_L[g])
                )
            )
    for g in range(n_G):
        for t in range(T):
            model.addConstr(gp.quicksum(lam[g, l, t] for l in range(n_L[g])) == u[g, t])
    for g in range(n_G):
        for l in range(n_L[g]):
            for t in range(T):
                model.addConstr(lam[g, l, t] <= 1)
    for g in range(n_G):
        for t in range(T - 1):
            model.addConstr(b[g, t] <= v[g, t])
    for g in range(n_G):
        for t in range(T - 1):
            model.addConstr(b[g, t] <= w[g, t + 1])
    for g in range(n_G):
        for t in range(T - 1):
            model.addConstr(b[g, t] >= v[g, t] + w[g, t + 1] - 1)

    # Objective
    model.setObjective(
        gp.quicksum(
            c_var[g, t] + C_fixed[g] * u[g, t] for g in range(n_G) for t in range(T)
        )
        + gp.quicksum(
            C_su[g][s] * d_su[g, s, t]
            for g in range(n_G)
            for s in range(n_S[g])
            for t in range(T)
        ),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["u"] = [[u[i, j].x for j in range(T)] for i in range(n_G)]
    variables["v"] = [[v[i, j].x for j in range(T)] for i in range(n_G)]
    variables["w"] = [[w[i, j].x for j in range(T)] for i in range(n_G)]
    variables["d_su"] = [
        [[d_su[g, s, t].x for t in range(T)] for s in range(n_S[g])] for g in range(n_G)
    ]
    variables["lam"] = [
        [[lam[g, l, t].x for t in range(T)] for l in range(n_L[g])] for g in range(n_G)
    ]
    variables["p"] = [[p[i, j].x for j in range(T)] for i in range(n_G)]
    variables["r"] = [[r[i, j].x for j in range(T)] for i in range(n_G)]
    variables["c_var"] = [[c_var[i, j].x for j in range(T)] for i in range(n_G)]
    variables["b"] = [[b[i, j].x for j in range(T - 1)] for i in range(n_G)]
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
