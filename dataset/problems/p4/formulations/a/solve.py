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
    # @Parameter CarCapacity @Def: The number of employees that a car can take @Shape: [] 
    CarCapacity = data['CarCapacity']
    # @Parameter CarPollution @Def: The pollution produced by a car @Shape: [] 
    CarPollution = data['CarPollution']
    # @Parameter BusCapacity @Def: The number of employees that a bus can take @Shape: [] 
    BusCapacity = data['BusCapacity']
    # @Parameter BusPollution @Def: The pollution produced by a bus @Shape: [] 
    BusPollution = data['BusPollution']
    # @Parameter MinEmployeesToTransport @Def: The minimum number of employees that need to be transported @Shape: [] 
    MinEmployeesToTransport = data['MinEmployeesToTransport']
    # @Parameter MaxBuses @Def: The maximum number of buses that can be used @Shape: [] 
    MaxBuses = data['MaxBuses']

    # Variables 
    # @Variable xCars @Def: The number of cars used for transportation @Shape: ['Integer'] 
    xCars = model.addVar(vtype=GRB.INTEGER, name="xCars")
    # @Variable xBuses @Def: The number of buses used for transportation @Shape: ['Integer'] 
    xBuses = model.addVar(vtype=GRB.INTEGER, lb=0, ub=MaxBuses, name="xBuses")

    # Constraints 
    # @Constraint Constr_1 @Def: At least MinEmployeesToTransport employees must be transported.
    model.addConstr(xCars * CarCapacity + xBuses * BusCapacity >= MinEmployeesToTransport)
    # @Constraint Constr_2 @Def: No more than MaxBuses buses can be used.


    # Objective 
    # @Objective Objective @Def: Total pollution produced is the sum of pollution from cars and buses. The objective is to minimize the total pollution produced.
    model.setObjective(xCars * CarPollution + xBuses * BusPollution, GRB.MINIMIZE)

    # Solve 
    model.optimize()

    # Extract solution 
    solution = {}
    variables = {}
    objective = []
    variables['xCars'] = xCars.x
    variables['xBuses'] = xBuses.x
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
