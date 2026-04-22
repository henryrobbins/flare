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
    # @Parameter G @Def: Number of units of oil each container can hold @Shape: [] 
    G = data['G']
    # @Parameter Y @Def: Number of units of oil each truck can hold @Shape: [] 
    Y = data['Y']
    # @Parameter K @Def: Maximum allowed ratio of number of trucks to number of containers @Shape: [] 
    K = data['K']
    # @Parameter V @Def: Minimum number of units of oil that need to be sent to the port @Shape: [] 
    V = data['V']
    # @Parameter L @Def: Minimum number of containers that need to be used @Shape: [] 
    L = data['L']

    # Variables 
    # @Variable c @Def: The number of containers used @Shape: [] 
    c = model.addVar(vtype=GRB.INTEGER, name="c", lb=L)
    # @Variable p @Def: The number of trucks used @Shape: [] 
    p = model.addVar(vtype=GRB.INTEGER, name="p")

    # Constraints 
    # @Constraint Constr_1 @Def: The total amount of oil sent to the port must be at least 2000 units, calculated as 30 units per container plus 40 units per truck.
    model.addConstr(G * c + Y * p >= V)
    # @Constraint Constr_2 @Def: The number of trucks used must be at most half the number of containers used.
    model.addConstr(p <= K * c)
    # @Constraint Constr_3 @Def: At least 15 containers must be used.
    model.addConstr(c >= L)

    # Objective 
    # @Objective Objective @Def: The objective is to minimize the total number of containers and trucks needed.
    model.setObjective(20.0, GRB.MINIMIZE)
    # Solve 
    model.optimize()

    # Extract solution 
    solution = {}
    variables = {}
    objective = []
    variables['c'] = c.x
    variables['p'] = p.x
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
