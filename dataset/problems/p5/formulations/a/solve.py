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
    # @Parameter WaterSubsoil @Def: Amount of water required to hydrate one bag of subsoil per day @Shape: []
    WaterSubsoil = data["WaterSubsoil"]
    # @Parameter WaterTopsoil @Def: Amount of water required to hydrate one bag of topsoil per day @Shape: []
    WaterTopsoil = data["WaterTopsoil"]
    # @Parameter MaxTotalBags @Def: Maximum number of bags of topsoil and subsoil combined @Shape: []
    MaxTotalBags = data["MaxTotalBags"]
    # @Parameter MinTopsoilBags @Def: Minimum number of topsoil bags to be used @Shape: []
    MinTopsoilBags = data["MinTopsoilBags"]
    # @Parameter MaxTopsoilProportion @Def: Maximum proportion of bags that can be topsoil @Shape: []
    MaxTopsoilProportion = data["MaxTopsoilProportion"]

    # Variables
    # @Variable SubsoilBags @Def: The number of subsoil bags @Shape: []
    SubsoilBags = model.addVar(vtype=GRB.INTEGER, name="SubsoilBags")
    # @Variable TopsoilBags @Def: The number of topsoil bags @Shape: []
    TopsoilBags = model.addVar(vtype=GRB.INTEGER, name="TopsoilBags")

    # Constraints
    # @Constraint Constr_1 @Def: The total number of subsoil and topsoil bags combined must not exceed MaxTotalBags.
    model.addConstr(SubsoilBags + TopsoilBags <= MaxTotalBags)
    # @Constraint Constr_2 @Def: At least MinTopsoilBags bags of topsoil must be used.
    model.addConstr(TopsoilBags >= MinTopsoilBags)
    # @Constraint Constr_3 @Def: The proportion of topsoil bags must not exceed MaxTopsoilProportion of all bags.
    model.addConstr(TopsoilBags <= MaxTopsoilProportion * (TopsoilBags + SubsoilBags))

    # Objective
    # @Objective Objective @Def: Total water required is the sum of (WaterSubsoil * number of subsoil bags) and (WaterTopsoil * number of topsoil bags). The objective is to minimize the total water required.
    model.setObjective(
        WaterSubsoil * SubsoilBags + WaterTopsoil * TopsoilBags, GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
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
