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
    nH = data["nH"]
    nC = data["nC"]
    a = data["a"]
    C = data["C"]
    t = data["t"]
    T = data["T"]
    n = data["n"]
    Hf = data["Hf"]
    M = data["M"]

    # Parameter Validation
    assert nH > 0
    assert nC > 0
    assert all(a[c] >= 0 for c in range(nC))
    assert all(C[h][c] >= 0 for h in range(nH) for c in range(nC))
    assert all(t[h][c] >= 0 for h in range(nH) for c in range(nC))
    assert all(Hf[h] in (0, 1) for h in range(nH))
    assert M > 0

    # Variables
    q = model.addVars(nH, nC, vtype=GRB.CONTINUOUS, name="q")
    z = model.addVars(nH, nC, vtype=GRB.BINARY, name="z")
    y = model.addVars(nH, vtype=GRB.BINARY, name="y")

    # Constraints
    model.addConstrs(q[h, c] <= M * z[h, c] for h in range(nH) for c in range(nC))
    model.addConstrs(gp.quicksum(q[h, c] for h in range(nH)) == 1 for c in range(nC))
    model.addConstrs(
        gp.quicksum(z[h, c] for c in range(nC)) <= nC * y[h] for h in range(nH)
    )
    model.addConstr(gp.quicksum(y[h] for h in range(nH)) <= n)
    model.addConstrs(y[h] == 1 for h in range(nH) if Hf[h] == 1)
    model.addConstrs(
        gp.quicksum(t[h][c] * q[h, c] for h in range(nH)) <= T for c in range(nC)
    )

    # Implicit Constraints
    model.addConstrs(q[h, c] >= 0 for h in range(nH) for c in range(nC))

    # Objective
    model.setObjective(
        gp.quicksum(a[c] * C[h][c] * q[h, c] for h in range(nH) for c in range(nC)),
        GRB.MINIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["q"] = [[q[i, j].x for j in range(nC)] for i in range(nH)]
    variables["z"] = [[z[i, j].x for j in range(nC)] for i in range(nH)]
    variables["y"] = [y[i].x for i in range(nH)]
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
