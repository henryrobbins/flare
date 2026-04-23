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
    CashMachineProcessingRate = data["CashMachineProcessingRate"]
    CardMachineProcessingRate = data["CardMachineProcessingRate"]
    CashMachinePaperRolls = data["CashMachinePaperRolls"]
    CardMachinePaperRolls = data["CardMachinePaperRolls"]
    MinPeopleProcessed = data["MinPeopleProcessed"]
    MaxPaperRolls = data["MaxPaperRolls"]

    # Parameter Validation
    assert CashMachineProcessingRate >= 0
    assert CardMachineProcessingRate >= 0
    assert CashMachinePaperRolls >= 0
    assert CardMachinePaperRolls >= 0
    assert MinPeopleProcessed >= 0
    assert MaxPaperRolls >= 0

    # Variables
    NumCashMachines = model.addVar(vtype=GRB.INTEGER, name="NumCashMachines")
    NumCardMachines = model.addVar(vtype=GRB.INTEGER, name="NumCardMachines")

    # Constraints
    model.addConstr(
        CashMachineProcessingRate * NumCashMachines
        + CardMachineProcessingRate * NumCardMachines
        >= MinPeopleProcessed
    )
    model.addConstr(
        NumCashMachines * CashMachinePaperRolls
        + NumCardMachines * CardMachinePaperRolls
        <= MaxPaperRolls
    )
    model.addConstr(NumCardMachines <= NumCashMachines)

    # Implicit Constraints
    model.addConstr(NumCashMachines >= 0)
    model.addConstr(NumCardMachines >= 0)

    # Objective
    model.setObjective(NumCashMachines + NumCardMachines, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["NumCashMachines"] = NumCashMachines.x
    variables["NumCardMachines"] = NumCardMachines.x
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
