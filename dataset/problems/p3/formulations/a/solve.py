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
    # @Parameter NumBeakers @Def: Number of beakers @Shape: [] 
    NumBeakers = data['NumBeakers']
    # @Parameter FlourAvailable @Def: Amount of flour available @Shape: [] 
    FlourAvailable = data['FlourAvailable']
    # @Parameter SpecialLiquidAvailable @Def: Amount of special liquid available @Shape: [] 
    SpecialLiquidAvailable = data['SpecialLiquidAvailable']
    # @Parameter MaxWasteAllowed @Def: Maximum amount of waste allowed @Shape: [] 
    MaxWasteAllowed = data['MaxWasteAllowed']
    # @Parameter FlourUsagePerBeaker @Def: Amount of flour used by each beaker @Shape: ['NumBeakers'] 
    FlourUsagePerBeaker = data['FlourUsagePerBeaker']
    # @Parameter SpecialLiquidUsagePerBeaker @Def: Amount of special liquid used by each beaker @Shape: ['NumBeakers'] 
    SpecialLiquidUsagePerBeaker = data['SpecialLiquidUsagePerBeaker']
    # @Parameter SlimeProducedPerBeaker @Def: Amount of slime produced by each beaker @Shape: ['NumBeakers'] 
    SlimeProducedPerBeaker = data['SlimeProducedPerBeaker']
    # @Parameter WasteProducedPerBeaker @Def: Amount of waste produced by each beaker @Shape: ['NumBeakers'] 
    WasteProducedPerBeaker = data['WasteProducedPerBeaker']

    # Variables 
    # @Variable FlourUsedPerBeaker @Def: The amount of flour used by beaker i @Shape: ['NumBeakers'] 
    FlourUsedPerBeaker = model.addVars(NumBeakers, vtype=GRB.CONTINUOUS, name="FlourUsedPerBeaker")

    # Constraints 
    # @Constraint Constr_1 @Def: The total amount of flour used by all beakers does not exceed FlourAvailable.
    model.addConstr(quicksum(FlourUsedPerBeaker[i] for i in range(NumBeakers)) <= FlourAvailable)
    # @Constraint Constr_2 @Def: The total amount of special liquid used by all beakers does not exceed SpecialLiquidAvailable.
    model.addConstr(quicksum(SpecialLiquidUsagePerBeaker[i] * FlourUsedPerBeaker[i] for i in range(NumBeakers)) <= SpecialLiquidAvailable)
    # @Constraint Constr_3 @Def: The total amount of waste produced by all beakers does not exceed MaxWasteAllowed.
    model.addConstr(quicksum(WasteProducedPerBeaker[i] * FlourUsedPerBeaker[i] for i in range(NumBeakers)) <= MaxWasteAllowed)

    # Objective 
    # @Objective Objective @Def: The total amount of slime produced by all beakers is maximized.
    model.setObjective(quicksum(SlimeProducedPerBeaker[i] * FlourUsedPerBeaker[i] for i in range(NumBeakers)), GRB.MAXIMIZE)

    # Solve 
    model.optimize()

    # Extract solution 
    solution = {}
    variables = {}
    objective = []
    variables['FlourUsedPerBeaker'] = {i: FlourUsedPerBeaker[i].X for i in range(NumBeakers)}
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
