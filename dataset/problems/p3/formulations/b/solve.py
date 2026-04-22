import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # @Def: definition of a target
    # @Shape: shape of a target

    # Parameters
    # @Parameter N @Def: Number of beakers @Shape: []
    N = data["N"]
    # @Parameter D @Def: Amount of flour available @Shape: []
    D = data["D"]
    # @Parameter Z @Def: Amount of special liquid available @Shape: []
    Z = data["Z"]
    # @Parameter E @Def: Maximum amount of waste allowed @Shape: []
    E = data["E"]
    # @Parameter T @Def: Amount of flour used by each beaker @Shape: ['N']
    T = data["T"]
    # @Parameter V @Def: Amount of special liquid used by each beaker @Shape: ['N']
    V = data["V"]
    # @Parameter X @Def: Amount of slime produced by each beaker @Shape: ['N']
    X = data["X"]
    # @Parameter C @Def: Amount of waste produced by each beaker @Shape: ['N']
    C = data["C"]

    # Variables
    # @Variable n @Def: The amount of flour used by beaker i @Shape: ['N']
    n = model.addVars(N, vtype=GRB.CONTINUOUS, name="n")

    # Constraints
    # @Constraint Constr_1 @Def: The total amount of flour used by all beakers does not exceed D.
    model.addConstr(quicksum(n[i] for i in range(N)) <= D)
    # @Constraint Constr_2 @Def: The total amount of special liquid used by all beakers does not exceed Z.
    model.addConstr(quicksum(V[i] * n[i] for i in range(N)) <= Z)
    # @Constraint Constr_3 @Def: The total amount of waste produced by all beakers does not exceed E.
    model.addConstr(quicksum(C[i] * n[i] for i in range(N)) <= E)

    # Objective
    # @Objective Objective @Def: The total amount of slime produced by all beakers is maximized.
    model.setObjective(quicksum(X[i] * n[i] for i in range(N)), GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
    variables["n"] = {i: n[i].X for i in range(N)}
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
