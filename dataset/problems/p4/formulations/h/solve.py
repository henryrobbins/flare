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
    # @Parameter V @Def: Number of bags a runner can carry each trip @Shape: []
    V = data["V"]
    # @Parameter U @Def: Time a runner takes per trip (in hours) @Shape: []
    U = data["U"]
    # @Parameter Z @Def: Number of bags a canoeer can carry each trip @Shape: []
    Z = data["Z"]
    # @Parameter N @Def: Time a canoeer takes per trip (in hours) @Shape: []
    N = data["N"]
    # @Parameter P @Def: Maximum fraction of total deliveries that can be made by canoe @Shape: []
    P = data["P"]
    # @Parameter C @Def: Maximum total hours the village can spare for deliveries @Shape: []
    C = data["C"]
    # @Parameter E @Def: Minimum number of runners that must be used @Shape: []
    E = data["E"]

    # Variables
    # @Variable a @Def: Number of trips made by runners @Shape: ['Integer']
    a = model.addVar(vtype=GRB.INTEGER, name="a")
    # @Variable p @Def: Number of trips made by canoeers @Shape: ['Integer']
    p = model.addVar(vtype=GRB.INTEGER, name="p")
    # @Variable e @Def: The number of runners used for deliveries @Shape: ['Integer']
    e = model.addVar(vtype=GRB.INTEGER, lb=E, name="e")

    # Constraints
    # @Constraint Constr_1 @Def: The total hours spent on deliveries by runners and canoeers must not exceed C.
    model.addConstr(U * a + N * p <= C)
    # @Constraint Constr_2 @Def: No more than P of the total mail delivered can be delivered by canoeers.
    model.addConstr(p * Z <= P * (a * V + p * Z))
    # @Constraint Constr_3 @Def: At least E runners must be used for deliveries.
    model.addConstr(e >= E)

    # Objective
    # @Objective Objective @Def: Maximize the total amount of mail delivered by runners and canoeers within the given time, capacity, and usage constraints.
    model.setObjective(a * V + p * Z, GRB.MAXIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    objective = []
    variables["a"] = a.x
    variables["p"] = p.x
    variables["e"] = e.x
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
