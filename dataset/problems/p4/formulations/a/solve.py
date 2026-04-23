import json
from gurobipy import Model, GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    CarCapacity = data["CarCapacity"]
    CarPollution = data["CarPollution"]
    BusCapacity = data["BusCapacity"]
    BusPollution = data["BusPollution"]
    MinEmployeesToTransport = data["MinEmployeesToTransport"]
    MaxBuses = data["MaxBuses"]

    # Parameter Validation
    assert CarCapacity >= 0
    assert CarPollution >= 0
    assert BusCapacity >= 0
    assert BusPollution >= 0
    assert MinEmployeesToTransport >= 0
    assert MaxBuses >= 0

    # Variables
    xCars = model.addVar(vtype=GRB.INTEGER, name="xCars")
    xBuses = model.addVar(vtype=GRB.INTEGER, name="xBuses")

    # Constraints
    model.addConstr(
        xCars * CarCapacity + xBuses * BusCapacity >= MinEmployeesToTransport
    )
    model.addConstr(xBuses <= MaxBuses)

    # Implicit Constraints
    model.addConstr(xCars >= 0)
    model.addConstr(xBuses >= 0)

    # Objective
    model.setObjective(xCars * CarPollution + xBuses * BusPollution, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["xCars"] = xCars.x
    variables["xBuses"] = xBuses.x
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
