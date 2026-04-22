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
    # @Parameter D @Def: Capacity of a vintage bottle in milliliters @Shape: []
    D = data["D"]
    # @Parameter J @Def: Capacity of a regular bottle in milliliters @Shape: []
    J = data["J"]
    # @Parameter A @Def: Total available vine in milliliters @Shape: []
    A = data["A"]
    # @Parameter O @Def: Minimum ratio of regular bottles to vintage bottles @Shape: []
    O = data["O"]
    # @Parameter Q @Def: Minimum number of vintage bottles to be produced @Shape: []
    Q = data["Q"]

    # Variables
    # @Variable g @Def: The number of vintage bottles to produce @Shape: []
    g = model.addVar(vtype=GRB.INTEGER, lb=Q, name="g")
    # @Variable z @Def: The number of regular bottles to produce @Shape: []
    z = model.addVar(vtype=GRB.INTEGER, name="z")

    # Constraints
    # @Constraint Constr_1 @Def: The total amount of vine used by vintage and regular bottles must not exceed A milliliters.
    model.addConstr(D * g + J * z <= A)
    # @Constraint Constr_2 @Def: The number of regular bottles must be at least O times the number of vintage bottles.
    model.addConstr(z >= O * g)
    # @Constraint Constr_3 @Def: At least Q vintage bottles must be produced.
    model.addConstr(g >= Q)

    # Objective
    # @Objective Objective @Def: Maximize the total number of bottles produced.
    model.setObjective(g + z, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
    variables["g"] = g.x
    variables["z"] = z.x
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
