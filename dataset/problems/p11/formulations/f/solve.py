import json
import gurobipy as gp
from gurobipy import GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = gp.Model()
    model.setParam("OutputFlag", 0)
    model.setParam("TimeLimit", 3600)

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    T = data['T']
    n_G = data['n_G']
    n_W = data['n_W']
    n_S = data['n_S']
    ell = data['ell']
    C_su = data['C_su']
    n_L = data['n_L']
    P = data['P']
    C = data['C']
    C_fixed = data['C_fixed']
    L = data['L']
    R = data['R']
    P_min = data['P_min']
    P_max = data['P_max']
    P_wind_min = data['P_wind_min']
    P_wind_max = data['P_wind_max']
    RU = data['RU']
    RD = data['RD']
    SU = data['SU']
    SD = data['SD']
    U = data['U']
    D = data['D']
    MR = data['MR']

    # Variables
    u = model.addVars(n_G, T, vtype=GRB.BINARY, name="u")
    v = model.addVars(n_G, T, vtype=GRB.BINARY, name="v")
    w = model.addVars(n_G, T, vtype=GRB.BINARY, name="w")
    d_su = {}
    for g in range(n_G):
        for s in range(n_S[g]):
            for t in range(T):
                d_su[g, s, t] = model.addVar(vtype=GRB.BINARY, name=f"d_su_{g}_{s}_{t}")
    lam = {}
    for g in range(n_G):
        for l in range(n_L[g]):
            for t in range(T):
                lam[g, l, t] = model.addVar(lb=0.0, ub=1.0, vtype=GRB.CONTINUOUS, name=f"lam_{g}_{l}_{t}")
    p = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="p")
    r = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="r")
    c_var = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="c_var")
    if n_W > 0:
        p_wind = model.addVars(n_W, T, lb=0.0, vtype=GRB.CONTINUOUS, name="p_wind")

    # EC3a: P_bar variable
    # @Variable P_bar @Def: Maximum reachable output of generator g at time t @Shape: [n_G, T]
    P_bar = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="P_bar")

    model.update()

    # Base constraints
    for t in range(T):
        thermal_sum = gp.quicksum(p[g, t] + P_min[g] * u[g, t] for g in range(n_G))
        if n_W > 0:
            wind_sum = gp.quicksum(p_wind[w_idx, t] for w_idx in range(n_W))
            model.addConstr(thermal_sum + wind_sum == L[t])
        else:
            model.addConstr(thermal_sum == L[t])

    model.addConstrs(
        gp.quicksum(r[g, t] for g in range(n_G)) >= R[t]
        for t in range(T)
    )

    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(u[g, t] - u[g, t-1] == v[g, t] - w[g, t])

    for g in range(n_G):
        for t in range(U[g]-1, T):
            model.addConstr(
                gp.quicksum(v[g, tau] for tau in range(t - U[g] + 1, t + 1)) <= u[g, t]
            )

    for g in range(n_G):
        for t in range(D[g]-1, T):
            model.addConstr(
                gp.quicksum(w[g, tau] for tau in range(t - D[g] + 1, t + 1)) <= 1 - u[g, t]
            )

    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                v[g, t] == gp.quicksum(d_su[g, s, t] for s in range(n_S[g]))
            )

    for g in range(n_G):
        for s in range(n_S[g] - 1):
            for t in range(ell[g][s+1] - 1, T):
                model.addConstr(
                    d_su[g, s, t] <= gp.quicksum(
                        w[g, t - i] for i in range(ell[g][s], ell[g][s+1])
                    )
                )

    for g in range(n_G):
        if MR[g] > 0:
            for t in range(T):
                model.addConstr(u[g, t] >= MR[g])

    for g in range(n_G):
        su_derate = max(P_max[g] - SU[g], 0)
        for t in range(T):
            model.addConstr(
                p[g, t] + r[g, t] <= (P_max[g] - P_min[g]) * u[g, t] - su_derate * v[g, t]
            )

    for g in range(n_G):
        sd_derate = max(P_max[g] - SD[g], 0)
        for t in range(T - 1):
            model.addConstr(
                p[g, t] + r[g, t] <= (P_max[g] - P_min[g]) * u[g, t] - sd_derate * w[g, t+1]
            )

    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t] + r[g, t] - p[g, t-1] <= RU[g])

    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t-1] - p[g, t] <= RD[g])

    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                p[g, t] == gp.quicksum((P[g][l] - P[g][0]) * lam[g, l, t] for l in range(n_L[g]))
            )

    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                c_var[g, t] == gp.quicksum((C[g][l] - C_fixed[g]) * lam[g, l, t] for l in range(n_L[g]))
            )

    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                gp.quicksum(lam[g, l, t] for l in range(n_L[g])) == u[g, t]
            )

    if n_W > 0:
        for w_idx in range(n_W):
            for t in range(T):
                model.addConstr(p_wind[w_idx, t] >= P_wind_min[w_idx][t])
                model.addConstr(p_wind[w_idx, t] <= P_wind_max[w_idx][t])

    # EC3a: Ramp-Up Reachability from Previous Period
    # @Constraint EC3a @Def: P_bar[g,t] <= P_min[g]*u[g,t] + p[g,t-1] + RU[g] + (P_max[g]-P_min[g])*(1-u[g,t-1])
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(
                P_bar[g, t] <= P_min[g] * u[g, t] + p[g, t - 1] + RU[g] + (P_max[g] - P_min[g]) * (1 - u[g, t - 1])
            )

    # Objective
    obj = gp.quicksum(c_var[g, t] + C_fixed[g] * u[g, t] for g in range(n_G) for t in range(T))
    obj += gp.quicksum(C_su[g][s] * d_su[g, s, t] for g in range(n_G) for s in range(n_S[g]) for t in range(T))
    model.setObjective(obj, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    if model.SolCount > 0:
        variables['u'] = [[u[g, t].x for t in range(T)] for g in range(n_G)]
        variables['v'] = [[v[g, t].x for t in range(T)] for g in range(n_G)]
        variables['w'] = [[w[g, t].x for t in range(T)] for g in range(n_G)]
        variables['d_su'] = [
            [[d_su[g, s, t].x for t in range(T)] for s in range(n_S[g])]
            for g in range(n_G)
        ]
        variables['lam'] = [
            [[lam[g, l, t].x for t in range(T)] for l in range(n_L[g])]
            for g in range(n_G)
        ]
        variables['p'] = [[p[g, t].x for t in range(T)] for g in range(n_G)]
        variables['r'] = [[r[g, t].x for t in range(T)] for g in range(n_G)]
        variables['c_var'] = [[c_var[g, t].x for t in range(T)] for g in range(n_G)]
        variables['P_bar'] = [[P_bar[g, t].x for t in range(T)] for g in range(n_G)]
        if n_W > 0:
            variables['p_wind'] = [[p_wind[w_idx, t].x for t in range(T)] for w_idx in range(n_W)]
        solution['variables'] = variables
        solution['objective'] = model.objVal
    else:
        solution['variables'] = {}
        solution['objective'] = None
        solution['status'] = model.Status

    with open(solution_path, 'w') as f:
        json.dump(solution, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("params", help="Path to parameters.json")
    parser.add_argument("solution", help="Path to write solution.json")
    args = parser.parse_args()
    main(args.params, args.solution)
