import json
from gurobipy import Model, GRB, quicksum
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # Parameters
    NumExperiments = data["NumExperiments"]
    NumResources = data["NumResources"]
    ResourceAvailable = data["ResourceAvailable"]
    ResourceRequired = data["ResourceRequired"]
    ElectricityProduced = data["ElectricityProduced"]

    # Variables
    ConductExperiment = model.addVars(
        NumExperiments, vtype=GRB.INTEGER, name="ConductExperiment"
    )

    # Constraints
    model.addConstrs(
        quicksum(
            ResourceRequired[j][i] * ConductExperiment[i] for i in range(NumExperiments)
        )
        <= ResourceAvailable[j]
        for j in range(NumResources)
    )

    # Objective
    model.setObjective(
        quicksum(
            ConductExperiment[i] * ElectricityProduced[i] for i in range(NumExperiments)
        ),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["ConductExperiment"] = [
        ConductExperiment[i].x for i in range(NumExperiments)
    ]
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
