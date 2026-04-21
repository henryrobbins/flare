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
    A = data['A']
    # @Parameter K @Def: Processing rate of a card-only machine in people per hour @Shape: [] 
    K = data['K']
    # @Parameter Y @Def: Number of paper rolls used per hour by a cash-based machine @Shape: [] 
    Y = data['Y']
    # @Parameter W @Def: Number of paper rolls used per hour by a card-only machine @Shape: [] 
    W = data['W']
    # @Parameter U @Def: Minimum number of people that must be processed per hour @Shape: [] 
    U = data['U']
    # @Parameter V @Def: Maximum number of paper rolls that can be used per hour @Shape: [] 
    V = data['V']

    # Variables 
    # @Variable s @Def: The number of cash-based machines @Shape: [] 
    s_0 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="s_0")
    s_1 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="s_1")
    # @Variable r @Def: The number of card-only machines @Shape: [] 
    r_0 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="r_0")
    r_1 = model.addVar(vtype=GRB.INTEGER, lb=0, ub=9, name="r_1")

    # Constraints 
    # @Constraint Constr_1 @Def: The total number of people processed per hour by cash-based and card-only machines must be at least U.
    model.addConstr(A*(s_0*10**0 + s_1*10**1)+K*(r_0*10**0 + r_1*10**1)>=U)# @Constraint Constr_2 @Def: The total number of paper rolls used per hour by cash-based and card-only machines must not exceed V.
    model.addConstr((s_0*10**0 + s_1*10**1)*Y+(r_0*10**0 + r_1*10**1)*W<=V)# @Constraint Constr_3 @Def: The number of card-only machines must not exceed the number of cash-based machines.
    model.addConstr((r_0*10**0 + r_1*10**1)<=(s_0*10**0 + s_1*10**1))
    # Objective 
    # @Objective Objective @Def: Minimize the total number of machines in the park.
    model.setObjective((s_0*10**0 + s_1*10**1)+(r_0*10**0 + r_1*10**1),GRB.MINIMIZE)
    # Solve 
    model.optimize()

    # Extract solution 
    solution = {}
    variables = {}
    objective = []
    variables['s_0'] = s_0.x
    variables['s_1'] = s_1.x
    variables['r_0'] = r_0.x
    variables['r_1'] = r_1.x
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
