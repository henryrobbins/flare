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
    J = data["J"]
    M = data["M"]
    K = data["K"]
    D = data["D"]
    O = data["O"]
    S = data["S"]

    # Parameter Validation
    assert J >= 0
    assert M >= 0
    assert K >= 0
    assert D >= 0
    assert O >= 0
    assert S >= 0

    # Variables
    m_0 = model.addVar(vtype=GRB.INTEGER, name="m_0")
    m_1 = model.addVar(vtype=GRB.INTEGER, name="m_1")
    h_0 = model.addVar(vtype=GRB.INTEGER, name="h_0")
    h_1 = model.addVar(vtype=GRB.INTEGER, name="h_1")

    # Constraints
    model.addConstr((h_0 * 10**0 + h_1 * 10**1) <= S)
    model.addConstr(
        (m_0 * 10**0 + m_1 * 10**1) * K + (h_0 * 10**0 + h_1 * 10**1) * D >= J
    )

    # Implicit Constraints
    model.addConstr(m_0 >= 0)
    model.addConstr(m_1 >= 0)
    model.addConstr(h_0 >= 0)
    model.addConstr(h_1 >= 0)
    model.addConstr(m_0 <= 9)
    model.addConstr(m_1 <= 9)
    model.addConstr(h_0 <= 9)
    model.addConstr(h_1 <= 9)

    # Objective
    model.setObjective(
        (m_0 * 10**0 + m_1 * 10**1) * M + (h_0 * 10**0 + h_1 * 10**1) * O, GRB.MINIMIZE
    )

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables["m_0"] = m_0.x
    variables["m_1"] = m_1.x
    variables["h_0"] = h_0.x
    variables["h_1"] = h_1.x
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
