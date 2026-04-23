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
    WaterSubsoil = data["WaterSubsoil"]
    WaterTopsoil = data["WaterTopsoil"]
    MaxTotalBags = data["MaxTotalBags"]
    MinTopsoilBags = data["MinTopsoilBags"]
    MaxTopsoilProportion = data["MaxTopsoilProportion"]

    # Parameter Validation
    assert WaterSubsoil >= 0
    assert WaterTopsoil >= 0
    assert MaxTotalBags >= 0
    assert MinTopsoilBags >= 0
    assert MaxTopsoilProportion >= 0

    # Variables
    SubsoilBags = model.addVar(vtype=GRB.INTEGER, name="SubsoilBags")
    TopsoilBags = model.addVar(vtype=GRB.INTEGER, name="TopsoilBags")

    # Constraints
    model.addConstr(SubsoilBags + TopsoilBags <= MaxTotalBags)
    model.addConstr(TopsoilBags >= MinTopsoilBags)
    model.addConstr(TopsoilBags <= MaxTopsoilProportion * (TopsoilBags + SubsoilBags))
    model.addConstr(SubsoilBags >= 0)
    model.addConstr(TopsoilBags >= 0)

    # Objective
    model.setObjective(
        WaterSubsoil * SubsoilBags + WaterTopsoil * TopsoilBags, GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["SubsoilBags"] = SubsoilBags.x
    variables["TopsoilBags"] = TopsoilBags.x
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
