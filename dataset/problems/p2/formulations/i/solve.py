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
    # @Parameter F @Def: Percentage of cat paw snacks in the first mix @Shape: []
    F = data["F"]
    # @Parameter M @Def: Percentage of cat paw snacks in the second mix @Shape: []
    M = data["M"]
    # @Parameter R @Def: Available kilograms of cat paw snacks @Shape: []
    R = data["R"]
    # @Parameter W @Def: Available kilograms of gold shark snacks @Shape: []
    W = data["W"]
    # @Parameter S @Def: Profit per kilogram of the first mix @Shape: []
    S = data["S"]
    # @Parameter Z @Def: Profit per kilogram of the second mix @Shape: []
    Z = data["Z"]

    # Variables
    # @Variable n @Def: The quantity of the first mix in kilograms @Shape: []
    n = model.addVar(vtype=GRB.CONTINUOUS, name="n")
    # @Variable v @Def: The quantity of the second mix in kilograms @Shape: []
    v = model.addVar(vtype=GRB.CONTINUOUS, name="v")

    # Constraints
    # @Constraint Constr_1 @Def: The total cat paw snacks used in both mixes must not exceed R kilograms, calculated as (F * n) + (M * v).
    model.addConstr(F * n + M * v <= R)
    # @Constraint Constr_2 @Def: The total gold shark snacks used in both mixes must not exceed W kilograms, calculated as ((100 - F) * n) + ((100 - M) * v).
    model.addConstr(((100 - F) / 100) * n + ((100 - M) / 100) * v <= W)

    # Objective
    # @Objective Objective @Def: The objective is to maximize the total profit, calculated as (S * n) + (Z * v).
    model.setObjective(1684.6153846153848, GRB.MAXIMIZE)
    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
    variables["n"] = n.x
    variables["v"] = v.x
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
