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
    # @Parameter NumExperiments @Def: Number of experiments @Shape: []
    NumExperiments = data["NumExperiments"]
    # @Parameter NumResources @Def: Number of resource types @Shape: []
    NumResources = data["NumResources"]
    # @Parameter ResourceAvailable @Def: Amount of resource j available @Shape: ['NumResources']
    ResourceAvailable = data["ResourceAvailable"]
    # @Parameter ResourceRequired @Def: Amount of resource j required for experiment i @Shape: ['NumResources', 'NumExperiments']
    ResourceRequired = data["ResourceRequired"]
    # @Parameter ElectricityProduced @Def: Amount of electricity produced by experiment i @Shape: ['NumExperiments']
    ElectricityProduced = data["ElectricityProduced"]

    # Variables
    # @Variable ConductExperiment @Def: The number of times each experiment is conducted @Shape: ['NumExperiments']
    ConductExperiment = model.addVars(
        NumExperiments, vtype=GRB.CONTINUOUS, name="ConductExperiment"
    )

    # Constraints
    # @Constraint Constr_1 @Def: The total metal required for all experiments does not exceed the available metal.
    model.addConstr(
        quicksum(
            ResourceRequired[0][i] * ConductExperiment[i] for i in range(NumExperiments)
        )
        <= ResourceAvailable[0]
    )
    # @Constraint Constr_2 @Def: The total acid required for all experiments does not exceed the available acid.
    model.addConstr(
        quicksum(
            ResourceRequired[1][i] * ConductExperiment[i] for i in range(NumExperiments)
        )
        <= ResourceAvailable[1]
    )

    # Objective
    # @Objective Objective @Def: Maximize the total electricity produced by conducting the experiments.
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
    objective = []
    variables["ConductExperiment"] = {
        i: ConductExperiment[i].X for i in range(NumExperiments)
    }
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
