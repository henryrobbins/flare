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
    NumBeakers = data["NumBeakers"]
    FlourAvailable = data["FlourAvailable"]
    SpecialLiquidAvailable = data["SpecialLiquidAvailable"]
    MaxWasteAllowed = data["MaxWasteAllowed"]
    FlourUsagePerBeaker = data["FlourUsagePerBeaker"]
    SpecialLiquidUsagePerBeaker = data["SpecialLiquidUsagePerBeaker"]
    SlimeProducedPerBeaker = data["SlimeProducedPerBeaker"]
    WasteProducedPerBeaker = data["WasteProducedPerBeaker"]

    # Variables
    NumBeakersUsed = model.addVars(NumBeakers, vtype=GRB.INTEGER, name="NumBeakersUsed")

    # Constraints
    model.addConstr(
        quicksum(FlourUsagePerBeaker[i] * NumBeakersUsed[i] for i in range(NumBeakers))
        <= FlourAvailable
    )
    model.addConstr(
        quicksum(
            SpecialLiquidUsagePerBeaker[i] * NumBeakersUsed[i]
            for i in range(NumBeakers)
        )
        <= SpecialLiquidAvailable
    )
    model.addConstr(
        quicksum(
            WasteProducedPerBeaker[i] * NumBeakersUsed[i] for i in range(NumBeakers)
        )
        <= MaxWasteAllowed
    )

    # Objective
    model.setObjective(
        quicksum(
            SlimeProducedPerBeaker[i] * NumBeakersUsed[i] for i in range(NumBeakers)
        ),
        GRB.MAXIMIZE,
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["NumBeakersUsed"] = [NumBeakersUsed[i].x for i in range(NumBeakers)]
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
