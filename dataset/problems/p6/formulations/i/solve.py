import json
import math
import gurobipy as gp
from gurobipy import GRB
import argparse


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
    # @Parameter n @Def: Number of customers @Shape: []
    n = data['n']
    # @Parameter m @Def: Number of candidate warehouses @Shape: []
    m = data['m']
    # @Parameter d @Def: Demand of customer i @Shape: [n]
    d = data['d']
    # @Parameter u @Def: Capacity of warehouse j @Shape: [m]
    u = data['u']
    # @Parameter f @Def: Fixed cost to open warehouse j @Shape: [m]
    f = data['f']
    # @Parameter c @Def: Transportation cost from warehouse j to customer i @Shape: [n, m]
    c = data['c']

    # Variables
    # @Variable x @Def: 1 if customer i is assigned to warehouse j, 0 otherwise @Shape: [n, m]
    x = model.addVars(n, m, vtype=GRB.BINARY, name="x")
    # @Variable y @Def: 1 if warehouse j is opened, 0 otherwise @Shape: [m]
    y = model.addVars(m, vtype=GRB.BINARY, name="y")

    # Constraints
    # @Constraint Constr_1 @Def: Each customer is assigned to exactly one warehouse.
    model.addConstrs(gp.quicksum(x[i, j] for j in range(m)) == 1 for i in range(n))
    # @Constraint Constr_2 @Def: Capacity constraint for each warehouse.
    model.addConstrs(gp.quicksum(d[i] * x[i, j] for i in range(n)) <= u[j] * y[j] for j in range(m))
    # @Constraint Constr_3 @Def: Warehouse Clique (EC5, Version 2).
    for j in range(m):
        C_j = [i for i in range(n) if d[i] > u[j] / 2]
        in_set = set(C_j)
        remaining = sorted(
            [i for i in range(n) if i not in in_set],
            key=lambda i: d[i], reverse=True
        )
        for i in remaining:
            if all(d[i] + d[i2] > u[j] for i2 in C_j):
                C_j.append(i)
        if C_j:
            model.addConstr(gp.quicksum(x[i, j] for i in C_j) <= y[j])

    # Objective
    # @Objective Objective @Def: Minimize total fixed opening cost plus transportation cost.
    model.setObjective(
        gp.quicksum(f[j] * y[j] for j in range(m)) +
        gp.quicksum(c[i][j] * x[i, j] for i in range(n) for j in range(m)),
        GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables['x'] = [[x[i, j].x for j in range(m)] for i in range(n)]
    variables['y'] = [y[j].x for j in range(m)]
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
