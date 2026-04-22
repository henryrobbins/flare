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
    # @Parameter N @Def: Size of the grid (number of rows and columns) @Shape: []
    N = data['N']

    # Index sets
    rows = range(N)
    cols = range(N)
    intervals = [(a, b) for a in range(N) for b in range(a, N)]

    # Variables
    # @Variable h @Def: 1 if (i,j) is the unique hole in row i and column j, 0 otherwise @Shape: [N, N]
    h = model.addVars(N, N, vtype=GRB.BINARY, name="h")
    # @Variable x @Def: 1 if row i, columns a through b are covered by the same tile, 0 otherwise @Shape: [N, |I|]
    x = model.addVars([(i, a, b) for i in rows for (a, b) in intervals], vtype=GRB.BINARY, name="x")
    # @Variable s @Def: 1 if a tile starts at row i for column interval (a,b), 0 otherwise @Shape: [N, |I|]
    s = model.addVars([(i, a, b) for i in rows for (a, b) in intervals], vtype=GRB.BINARY, name="s")
    # @Variable t @Def: 1 if a tile ends at row i for column interval (a,b), 0 otherwise @Shape: [N, |I|]
    t = model.addVars([(i, a, b) for i in rows for (a, b) in intervals], vtype=GRB.BINARY, name="t")

    # Base constraints
    # @Constraint Constr_1 @Def: Each row contains exactly one hole.
    model.addConstrs(gp.quicksum(h[i, j] for j in cols) == 1 for i in rows)
    # @Constraint Constr_2 @Def: Each column contains exactly one hole.
    model.addConstrs(gp.quicksum(h[i, j] for i in rows) == 1 for j in cols)
    # @Constraint Constr_3 @Def: Each cell is either a hole or covered by exactly one tile interval.
    model.addConstrs(
        gp.quicksum(x[i, a, b] for (a, b) in intervals if a <= j <= b) + h[i, j] == 1
        for i in rows for j in cols
    )
    # @Constraint Constr_4 @Def: Top-row flow.
    model.addConstrs(x[0, a, b] - s[0, a, b] == 0 for (a, b) in intervals)
    # @Constraint Constr_5 @Def: Mid-row flow.
    model.addConstrs(
        x[i, a, b] - x[i-1, a, b] - s[i, a, b] + t[i-1, a, b] == 0
        for i in range(1, N) for (a, b) in intervals
    )
    # @Constraint Constr_6 @Def: Bottom-row flow.
    model.addConstrs(x[N-1, a, b] - t[N-1, a, b] == 0 for (a, b) in intervals)

    # Cut: V2 EC1 Vacated Column
    # @Constraint Constr_7 @Def: If the hole vacates column j between rows i-1 and i, column j must be covered by a new strip start at row i.
    model.addConstrs(
        gp.quicksum(s[i, a, b] for (a, b) in intervals if a <= j <= b) >= h[i-1, j] - h[i, j]
        for i in range(1, N) for j in cols
    )

    # Objective
    # @Objective Objective @Def: Minimize the total number of rectangular tiles used.
    model.setObjective(
        gp.quicksum(s[i, a, b] for i in rows for (a, b) in intervals),
        GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables['h'] = [[h[i, j].x for j in cols] for i in rows]
    variables['x'] = {f"{a},{b}": [x[i, a, b].x for i in rows] for (a, b) in intervals}
    variables['s'] = {f"{a},{b}": [s[i, a, b].x for i in rows] for (a, b) in intervals}
    variables['t'] = {f"{a},{b}": [t[i, a, b].x for i in rows] for (a, b) in intervals}
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
