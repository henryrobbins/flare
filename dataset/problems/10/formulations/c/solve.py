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

    # @Def: definition of a target
    # @Shape: shape of a target

    # Parameters
    # @Parameter K @Def: Number of trucks/vehicles in the fleet @Shape: []
    K = data['K']
    # @Parameter N @Def: Number of pickup and delivery jobs @Shape: []
    N = data['N']
    # @Parameter d @Def: Travel time from job i's return terminal to job j's pickup terminal; d[i][i] is the loaded time (rejection penalty) of job i @Shape: [N, N]
    d = data['d']
    # @Parameter d0 @Def: Travel time from the home terminal of truck k to job i's pickup terminal @Shape: [K, N]
    d0 = data['d0']
    # @Parameter dH @Def: Travel time from job i's return terminal to the home terminal of truck k @Shape: [K, N]
    dH = data['dH']
    # @Parameter v @Def: Time at which each truck becomes available @Shape: [K]
    v = data['v']
    # @Parameter tau_min @Def: Earliest permissible arrival time at each job's pickup terminal @Shape: [N]
    tau_min = data['tau_min']
    # @Parameter tau_max @Def: Latest permissible arrival time at each job's pickup terminal @Shape: [N]
    tau_max = data['tau_max']

    # Big-M constant
    M = max(tau_max) + max(d[i][i] + d[i][j] for i in range(N) for j in range(N))

    # Variables
    # @Variable x @Def: 1 if arc (u,v) is selected in the routing cycle cover; x[K+i][K+i]=1 means job i is rejected @Shape: [K+N, K+N]
    x = model.addVars(K + N, K + N, vtype=GRB.BINARY, name="x")
    # @Variable delta @Def: Arrival time at job i's pickup terminal @Shape: [N]
    delta = model.addVars(N, lb=0, vtype=GRB.CONTINUOUS, name="delta")

    # Constraints
    # @Constraint Constr_1 @Def: Each node has exactly one outgoing arc.
    model.addConstrs(gp.quicksum(x[u, v] for v in range(K + N)) == 1 for u in range(K + N))
    # @Constraint Constr_2 @Def: Each node has exactly one incoming arc.
    model.addConstrs(gp.quicksum(x[v, u] for v in range(K + N)) == 1 for u in range(K + N))
    # @Constraint Constr_3 @Def: Arrival time at job i is at least the earliest possible arrival from any truck.
    model.addConstrs(
        delta[i] - gp.quicksum((d0[k][i] + v[k]) * x[k, K + i] for k in range(K)) >= 0
        for i in range(N)
    )
    # @Constraint Constr_4 @Def: Arrival time propagation between consecutive jobs via big-M.
    model.addConstrs(
        delta[j] - delta[i] - M * x[K + i, K + j] + (d[i][i] + d[i][j]) * x[K + i, K + i]
        >= d[i][i] + d[i][j] - M
        for i in range(N) for j in range(N)
    )
    # @Constraint Constr_5 @Def: Earliest time-window bound for each job's pickup.
    model.addConstrs(delta[i] >= tau_min[i] for i in range(N))
    # @Constraint Constr_6 @Def: Latest time-window bound for each job's pickup.
    model.addConstrs(delta[i] <= tau_max[i] for i in range(N))

    # EC2: Mutual Feasibility Pair cuts
    # Compute earliest possible arrival time at each job
    EST = [max(tau_min[i], min(v[k] + d0[k][i] for k in range(K))) for i in range(N)]
    # Compute set of infeasible job-to-job arcs
    A_minus = {(i, j) for i in range(N) for j in range(N) if EST[i] + d[i][i] + d[i][j] > tau_max[j]}
    # @Constraint EC2 @Def: For mutually feasible pairs, at most one of two sequencing directions or a rejection of i can hold.
    for i in range(N):
        for j in range(N):
            if i != j and (i, j) not in A_minus and (j, i) not in A_minus:
                model.addConstr(x[K + i, K + j] + x[K + j, K + i] + x[K + i, K + i] <= 1)

    # Objective
    # @Objective Objective @Def: Minimize total travel cost (deadhead from truck homes + inter-job + returns to truck homes).
    model.setObjective(
        gp.quicksum(d0[k][i] * x[k, K + i] for k in range(K) for i in range(N))
        + gp.quicksum(d[i][j] * x[K + i, K + j] for i in range(N) for j in range(N))
        + gp.quicksum(dH[k][i] * x[K + i, k] for i in range(N) for k in range(K)),
        GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables['x'] = [[x[u, v].x for v in range(K + N)] for u in range(K + N)]
    variables['delta'] = [delta[i].x for i in range(N)]
    solution['variables'] = variables
    solution['objective'] = model.objVal
    with open(solution_path, 'w') as f:
        json.dump(solution, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("params", help="Path to parameters.json")
    parser.add_argument("solution", help="Path to write solution.json")
    args = parser.parse_args()
    main(args.params, args.solution)
