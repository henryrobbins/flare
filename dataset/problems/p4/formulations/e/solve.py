import json
from gurobipy import *
import argparse


def main(params_path: str, solution_path: str) -> None:
    model = Model()
    slack_0 = model.addVar(lb=0, name='slack_0')
    with open(params_path, 'r') as f:
        data = json.load(f)
    K = data['K']
    M = data['M']
    D = data['D']
    O = data['O']
    J = data['J']
    S = data['S']
    m = model.addVar(vtype=GRB.INTEGER, name='m')
    h = model.addVar(vtype=GRB.INTEGER, lb=0, ub=S, name='h')
    model.addConstr(m * K + h * D - slack_0 == J)
    model.setObjective(m * M + h * O, GRB.MINIMIZE)
    model.optimize()
    solution = {}
    variables = {}
    variables['slack_0'] = slack_0.X
    objective = []
    variables['m'] = m.x
    variables['h'] = h.x
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
