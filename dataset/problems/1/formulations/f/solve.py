import json
from gurobipy import *
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
    # @Parameter A @Def: Processing rate of a cash-based machine in people per hour @Shape: []
    A = data["A"]
    # @Parameter K @Def: Processing rate of a card-only machine in people per hour @Shape: []
    K = data["K"]
    # @Parameter Y @Def: Number of paper rolls used per hour by a cash-based machine @Shape: []
    Y = data["Y"]
    # @Parameter W @Def: Number of paper rolls used per hour by a card-only machine @Shape: []
    W = data["W"]
    # @Parameter U @Def: Minimum number of people that must be processed per hour @Shape: []
    U = data["U"]
    # @Parameter V @Def: Maximum number of paper rolls that can be used per hour @Shape: []
    V = data["V"]

    # Variables

    # @Variable s1 @Def: Part 1 of variable (s1 + s2)@Shape: []
    s1 = model.addVar(
        vtype=GRB.INTEGER, name="s1"
    )  # @Variable r1 @Def: Part 1 of variable r @Shape: []
    r1 = model.addVar(vtype=GRB.INTEGER, name="r1")
    # @Variable r2 @Def: Part 2 of variable (r1 + r2)@Shape: []
    r2 = model.addVar(vtype=GRB.INTEGER, name="r2")

    # @Variable s2 @Def: Part 2 of variable (s1 + s2)@Shape: []
    s2 = model.addVar(vtype=GRB.INTEGER, name="s2")

    # Constraints
    # @Constraint Constr_1 @Def: The total number of people processed per hour by cash-based and card-only machines must be at least U.
    model.addConstr(A * (s1 + s2) + K * (r1 + r2) >= U)
    # @Constraint Constr_2 @Def: The total number of paper rolls used per hour by cash-based and card-only machines must not exceed V.
    model.addConstr((s1 + s2) * Y + (r1 + r2) * W <= V)
    # @Constraint Constr_3 @Def: The number of card-only machines must not exceed the number of cash-based machines.
    model.addConstr((r1 + r2) <= (s1 + s2))

    # Objective
    # @Objective Objective @Def: Minimize the total number of machines in the park.
    model.setObjective((s1 + s2) + (r1 + r2), GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["s1"] = s1.X
    variables["s2"] = s2.X
    variables["r1"] = r1.X
    variables["r2"] = r2.X
    objective = []
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
