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
    # @Parameter T @Def: Number of time periods @Shape: []
    T = data['T']
    # @Parameter n_G @Def: Number of thermal generators @Shape: []
    n_G = data['n_G']
    # @Parameter n_W @Def: Number of renewable (wind) generators @Shape: []
    n_W = data['n_W']
    # @Parameter n_S @Def: Number of startup categories per generator @Shape: [n_G]
    n_S = data['n_S']
    # @Parameter ell @Def: Startup lag for each startup category @Shape: [n_G, n_S[]]
    ell = data['ell']
    # @Parameter C_su @Def: Startup cost for each startup category @Shape: [n_G, n_S[]]
    C_su = data['C_su']
    # @Parameter n_L @Def: Number of piecewise breakpoints per generator @Shape: [n_G]
    n_L = data['n_L']
    # @Parameter P @Def: Piecewise production breakpoints @Shape: [n_G, n_L[]]
    P = data['P']
    # @Parameter C @Def: Piecewise cost breakpoints @Shape: [n_G, n_L[]]
    C = data['C']
    # @Parameter C_fixed @Def: Fixed on-cost per generator @Shape: [n_G]
    C_fixed = data['C_fixed']
    # @Parameter L @Def: Demand at each time period @Shape: [T]
    L = data['L']
    # @Parameter R @Def: Reserve requirement at each time period @Shape: [T]
    R = data['R']
    # @Parameter P_min @Def: Minimum thermal output @Shape: [n_G]
    P_min = data['P_min']
    # @Parameter P_max @Def: Maximum thermal output @Shape: [n_G]
    P_max = data['P_max']
    # @Parameter P_wind_min @Def: Minimum renewable output @Shape: [n_W, T]
    P_wind_min = data['P_wind_min']
    # @Parameter P_wind_max @Def: Maximum renewable output @Shape: [n_W, T]
    P_wind_max = data['P_wind_max']
    # @Parameter RU @Def: Ramp-up limit @Shape: [n_G]
    RU = data['RU']
    # @Parameter RD @Def: Ramp-down limit @Shape: [n_G]
    RD = data['RD']
    # @Parameter SU @Def: Startup ramp limit @Shape: [n_G]
    SU = data['SU']
    # @Parameter SD @Def: Shutdown ramp limit @Shape: [n_G]
    SD = data['SD']
    # @Parameter U @Def: Minimum up time @Shape: [n_G]
    U = data['U']
    # @Parameter D @Def: Minimum down time @Shape: [n_G]
    D = data['D']
    # @Parameter MR @Def: Must-run flag @Shape: [n_G]
    MR = data['MR']

    # Variables
    # @Variable u @Def: On status of generator g at time t @Shape: [n_G, T]
    u = model.addVars(n_G, T, vtype=GRB.BINARY, name="u")
    # @Variable v @Def: Startup indicator of generator g at time t @Shape: [n_G, T]
    v = model.addVars(n_G, T, vtype=GRB.BINARY, name="v")
    # @Variable w @Def: Shutdown indicator of generator g at time t @Shape: [n_G, T]
    w = model.addVars(n_G, T, vtype=GRB.BINARY, name="w")
    # @Variable d_su @Def: Startup category selection (ragged) @Shape: [n_G, n_S[], T]
    d_su = {}
    for g in range(n_G):
        for s in range(n_S[g]):
            for t in range(T):
                d_su[g, s, t] = model.addVar(vtype=GRB.BINARY, name=f"d_su_{g}_{s}_{t}")
    # @Variable lam @Def: Piecewise weight (ragged) @Shape: [n_G, n_L[], T]
    lam = {}
    for g in range(n_G):
        for l in range(n_L[g]):
            for t in range(T):
                lam[g, l, t] = model.addVar(lb=0.0, ub=1.0, vtype=GRB.CONTINUOUS, name=f"lam_{g}_{l}_{t}")
    # @Variable p @Def: Thermal output above P_min @Shape: [n_G, T]
    p = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="p")
    # @Variable r @Def: Spinning reserve @Shape: [n_G, T]
    r = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="r")
    # @Variable c_var @Def: Variable cost above fixed cost @Shape: [n_G, T]
    c_var = model.addVars(n_G, T, lb=0.0, vtype=GRB.CONTINUOUS, name="c_var")
    # @Variable p_wind @Def: Renewable output @Shape: [n_W, T]
    if n_W > 0:
        p_wind = model.addVars(n_W, T, lb=0.0, vtype=GRB.CONTINUOUS, name="p_wind")

    model.update()

    # Constraints
    # @Constraint Constr_1 @Def: Demand balance
    for t in range(T):
        thermal_sum = gp.quicksum(p[g, t] + P_min[g] * u[g, t] for g in range(n_G))
        if n_W > 0:
            wind_sum = gp.quicksum(p_wind[w_idx, t] for w_idx in range(n_W))
            model.addConstr(thermal_sum + wind_sum == L[t], name=f"demand_{t}")
        else:
            model.addConstr(thermal_sum == L[t], name=f"demand_{t}")

    # @Constraint Constr_2 @Def: Reserve requirement
    model.addConstrs(
        gp.quicksum(r[g, t] for g in range(n_G)) >= R[t]
        for t in range(T)
    )

    # @Constraint Constr_3 @Def: Commitment transition
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(u[g, t] - u[g, t-1] == v[g, t] - w[g, t])

    # @Constraint Constr_4 @Def: Minimum up time
    for g in range(n_G):
        for t in range(U[g]-1, T):
            model.addConstr(
                gp.quicksum(v[g, tau] for tau in range(t - U[g] + 1, t + 1)) <= u[g, t]
            )

    # @Constraint Constr_5 @Def: Minimum down time
    for g in range(n_G):
        for t in range(D[g]-1, T):
            model.addConstr(
                gp.quicksum(w[g, tau] for tau in range(t - D[g] + 1, t + 1)) <= 1 - u[g, t]
            )

    # @Constraint Constr_6 @Def: Startup decomposition
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                v[g, t] == gp.quicksum(d_su[g, s, t] for s in range(n_S[g]))
            )

    # @Constraint Constr_7 @Def: Startup category timing
    for g in range(n_G):
        for s in range(n_S[g] - 1):
            for t in range(ell[g][s+1] - 1, T):
                model.addConstr(
                    d_su[g, s, t] <= gp.quicksum(
                        w[g, t - i] for i in range(ell[g][s], ell[g][s+1])
                    )
                )

    # @Constraint Constr_8 @Def: Must-run
    for g in range(n_G):
        if MR[g] > 0:
            for t in range(T):
                model.addConstr(u[g, t] >= MR[g])

    # @Constraint Constr_9 @Def: Startup derating capacity bound
    for g in range(n_G):
        su_derate = max(P_max[g] - SU[g], 0)
        for t in range(T):
            model.addConstr(
                p[g, t] + r[g, t] <= (P_max[g] - P_min[g]) * u[g, t] - su_derate * v[g, t]
            )

    # @Constraint Constr_10 @Def: Shutdown derating capacity bound
    for g in range(n_G):
        sd_derate = max(P_max[g] - SD[g], 0)
        for t in range(T - 1):
            model.addConstr(
                p[g, t] + r[g, t] <= (P_max[g] - P_min[g]) * u[g, t] - sd_derate * w[g, t+1]
            )

    # @Constraint Constr_11 @Def: Ramp-up limit
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t] + r[g, t] - p[g, t-1] <= RU[g])

    # @Constraint Constr_12 @Def: Ramp-down limit
    for g in range(n_G):
        for t in range(1, T):
            model.addConstr(p[g, t-1] - p[g, t] <= RD[g])

    # @Constraint Constr_13 @Def: Piecewise production
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                p[g, t] == gp.quicksum((P[g][l] - P[g][0]) * lam[g, l, t] for l in range(n_L[g]))
            )

    # @Constraint Constr_14 @Def: Piecewise cost
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                c_var[g, t] == gp.quicksum((C[g][l] - C_fixed[g]) * lam[g, l, t] for l in range(n_L[g]))
            )

    # @Constraint Constr_15 @Def: Piecewise weights sum to on-status
    for g in range(n_G):
        for t in range(T):
            model.addConstr(
                gp.quicksum(lam[g, l, t] for l in range(n_L[g])) == u[g, t]
            )

    # @Constraint Constr_16 @Def: Renewable output bounds
    if n_W > 0:
        for w_idx in range(n_W):
            for t in range(T):
                model.addConstr(p_wind[w_idx, t] >= P_wind_min[w_idx][t])
                model.addConstr(p_wind[w_idx, t] <= P_wind_max[w_idx][t])

    # Objective
    # @Objective Objective @Def: Minimize total production and startup costs
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
