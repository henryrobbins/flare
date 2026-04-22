import json
from gurobipy import *
import argparse


def main(params_path: str, solution_path: str) -> None:
    model = Model()
    slack_1 = model.addVar(lb=0, name='slack_1')
    slack_2 = model.addVar(lb=0, name='slack_2')
    slack_0 = model.addVar(lb=0, name='slack_0')
    with open(params_path, 'r') as f:
        data = json.load(f)
    Z = data['Z']
    B = data['B']
    D = data['D']
    P = data['P']
    K = data['K']
    h = model.addVar(vtype=GRB.INTEGER, name='h')
    d = model.addVar(vtype=GRB.INTEGER, name='d')
    model.addConstr(h + d + slack_1 == D)
    model.addConstr(d - slack_2 == P)
    model.addConstr(d + slack_0 == K * (d + h))
    model.setObjective(Z * h + B * d, GRB.MINIMIZE)
    model.optimize()
    solution = {}
    variables = {}
    variables['slack_1'] = slack_1.X
    variables['slack_2'] = slack_2.X
    variables['slack_0'] = slack_0.X
    objective = []
    variables['h'] = h.x
    variables['d'] = d.x
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
