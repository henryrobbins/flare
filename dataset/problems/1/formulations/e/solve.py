import json
from gurobipy import *
import argparse


def main(params_path: str, solution_path: str) -> None:
    model = Model()
    slack_0 = model.addVar(lb=0, name='slack_0')
    slack_2 = model.addVar(lb=0, name='slack_2')
    slack_1 = model.addVar(lb=0, name='slack_1')
    with open(params_path, 'r') as f:
        data = json.load(f)
    A = data['A']
    K = data['K']
    Y = data['Y']
    W = data['W']
    U = data['U']
    V = data['V']
    s = model.addVar(vtype=GRB.INTEGER, name='s')
    r = model.addVar(vtype=GRB.INTEGER, name='r')
    model.addConstr(A * s + K * r - slack_0 == U)
    model.addConstr(s * Y + r * W + slack_2 == V)
    model.addConstr(r + slack_1 == s)
    model.setObjective(s + r, GRB.MINIMIZE)
    model.optimize()
    solution = {}
    variables = {}
    variables['slack_0'] = slack_0.X
    variables['slack_2'] = slack_2.X
    variables['slack_1'] = slack_1.X
    objective = []
    variables['s'] = s.x
    variables['r'] = r.x
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
