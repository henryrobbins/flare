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
    # @Parameter K @Def: The number of employees that a car can take @Shape: []
    K = data["K"]
    # @Parameter M @Def: The pollution produced by a car @Shape: []
    M = data["M"]
    # @Parameter D @Def: The number of employees that a bus can take @Shape: []
    D = data["D"]
    # @Parameter O @Def: The pollution produced by a bus @Shape: []
    O = data["O"]
    # @Parameter J @Def: The minimum number of employees that need to be transported @Shape: []
    J = data["J"]
    # @Parameter S @Def: The maximum number of buses that can be used @Shape: []
    S = data["S"]

    # Variables
    # @Variable m @Def: The number of cars used for transportation @Shape: ['Integer']
    m_0 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="m_0")
    m_1 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="m_1")
    # @Variable h @Def: The number of buses used for transportation @Shape: ['Integer']
    h_0 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="h_0")

    # Constraints
    # @Constraint Constr_1 @Def: At least J employees must be transported.
    model.addConstr(
        (m_0 * 10**0 + m_1 * 10**1) * K + (h_0 * 10**0) * D >= J
    )  # @Constraint Constr_2 @Def: No more than S buses can be used.

    # Objective
    # @Objective Objective @Def: Total pollution produced is the sum of pollution from cars and buses. The objective is to minimize the total pollution produced.
    model.setObjective(
        (m_0 * 10**0 + m_1 * 10**1) * M + (h_0 * 10**0) * O, GRB.MINIMIZE
    )
    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
    variables["m_0"] = m_0.x
    variables["m_1"] = m_1.x
    variables["h_0"] = h_0.x
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
