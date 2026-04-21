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
    # @Parameter M @Def: Number of experiments @Shape: [] 
    M = data['M']
    # @Parameter N @Def: Number of resource types @Shape: [] 
    N = data['N']
    # @Parameter Y @Def: Amount of resource (j1[{index}] + j2[{index}])available @Shape: ['N'] 
    Y = data['Y']
    # @Parameter I @Def: Amount of resource (j1[{index}] + j2[{index}])required for experiment i @Shape: ['N', 'M'] 
    I = data['I']
    # @Parameter A @Def: Amount of electricity produced by experiment i @Shape: ['M'] 
    A = data['A']

    # Variables 


    # Constraints # @Variable j1 @Def: Part 1 of variable (j1[{index}] + j2[{index}])@Shape: ['M']
    j1 = model.addVars(M, vtype=GRB.CONTINUOUS, name="j1")
    # @Variable j2 @Def: Part 2 of variable (j1[{index}] + j2[{index}])@Shape: ['M']
    j2 = model.addVars(M, vtype=GRB.CONTINUOUS, name="j2")

    # @Constraint Constr_1 @Def: The total metal required for all experiments does not exceed the available metal.
    model.addConstr(quicksum(I[0][i] * (j1[i] + j2[i]) for i in range(M)) <= Y[0])
    # @Constraint Constr_2 @Def: The total acid required for all experiments does not exceed the available acid.
    model.addConstr(quicksum(I[1][i] * (j1[i] + j2[i]) for i in range(M)) <= Y[1])

    # Objective 
    # @Objective Objective @Def: Maximize the total electricity produced by conducting the experiments.
    model.setObjective(quicksum((j1[i] + j2[i]) * A[i] for i in range(M)), GRB.MAXIMIZE)

    # Solve 
    model.optimize()

    # Extract solution 
    solution = {}
    variables = {}
    variables['j1'] = {i: j1[i].X for i in j1.keys()}
    variables['j2'] = {i: j2[i].X for i in j2.keys()}
    objective = []
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
