import json
import math
import gurobipy as gp
from gurobipy import GRB
import argparse
from itertools import combinations


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = gp.Model()
    model.setParam("OutputFlag", 0)

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # @Def: definition of a target
    # @Shape: shape of a target

    # Parameters
    # @Parameter n @Def: Number of network nodes @Shape: []
    n = data['n']
    # @Parameter m @Def: Number of candidate directed arcs @Shape: []
    m = data['m']
    # @Parameter K @Def: Number of commodities @Shape: []
    K = data['K']
    # @Parameter tail @Def: Source node index of each arc @Shape: [m]
    tail = data['tail']
    # @Parameter head @Def: Destination node index of each arc @Shape: [m]
    head = data['head']
    # @Parameter c @Def: Unit transportation cost on each arc @Shape: [m]
    c = data['c']
    # @Parameter f @Def: Fixed cost to activate each arc @Shape: [m]
    f = data['f']
    # @Parameter u @Def: Capacity of each arc @Shape: [m]
    u = data['u']
    # @Parameter O @Def: Origin node of each commodity @Shape: [K]
    O = data['O']
    # @Parameter D @Def: Destination node of each commodity @Shape: [K]
    D = data['D']
    # @Parameter d @Def: Demand of each commodity @Shape: [K]
    d = data['d']

    # Arc adjacency helpers
    out = {i: [a for a in range(m) if tail[a] == i] for i in range(n)}
    inc = {i: [a for a in range(m) if head[a] == i] for i in range(n)}

    # Variables
    # @Variable x @Def: Flow of commodity k on arc a @Shape: [m, K]
    x = model.addVars(m, K, lb=0, vtype=GRB.CONTINUOUS, name="x")
    # @Variable y @Def: 1 if arc a is activated, 0 otherwise @Shape: [m]
    y = model.addVars(m, vtype=GRB.BINARY, name="y")

    # Constraints
    # @Constraint Constr_1 @Def: Commodity source outflow equals demand.
    model.addConstrs(
        gp.quicksum(x[a, k] for a in out[O[k]]) == d[k]
        for k in range(K)
    )
    # @Constraint Constr_2 @Def: Commodity sink inflow equals demand.
    model.addConstrs(
        gp.quicksum(x[a, k] for a in inc[D[k]]) == d[k]
        for k in range(K)
    )
    # @Constraint Constr_3 @Def: Flow conservation at intermediate nodes.
    model.addConstrs(
        gp.quicksum(x[a, k] for a in out[i]) - gp.quicksum(x[a, k] for a in inc[i]) == 0
        for k in range(K) for i in range(n) if i != O[k] and i != D[k]
    )
    # @Constraint Constr_4 @Def: Arc capacity: total flow cannot exceed capacity times activation.
    model.addConstrs(
        gp.quicksum(x[a, k] for k in range(K)) <= u[a] * y[a]
        for a in range(m)
    )
    # @Constraint Constr_5 @Def: Destination In-Cut Bound (V1 EC1).
    for k in range(K):
        inc_dk = inc[D[k]]
        if not inc_dk:
            continue
        u_max_k = max(u[a] for a in inc_dk)
        model.addConstr(
            gp.quicksum((u[a] + u_max_k) * y[a] for a in inc_dk) >= d[k] + u_max_k
        )

    # Objective
    # @Objective Objective @Def: Minimize total flow cost plus fixed arc activation cost.
    model.setObjective(
        gp.quicksum(c[a] * x[a, k] for a in range(m) for k in range(K)) +
        gp.quicksum(f[a] * y[a] for a in range(m)),
        GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables['x'] = [[x[a, k].x for k in range(K)] for a in range(m)]
    variables['y'] = [y[a].x for a in range(m)]
    solution['variables'] = variables
    solution['objective'] = model.objVal
    with open(solution_path, 'w') as f_out:
        json.dump(solution, f_out, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("params", help="Path to parameters.json")
    parser.add_argument("solution", help="Path to write solution.json")
    args = parser.parse_args()
    main(args.params, args.solution)
