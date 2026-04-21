"""
An amusement park is installing cash-based machines and card-only machines. A
cash-based machine can process A people per hour, while
a card-only machine can process K people per hour. The
cash-based machine needs Y rolls of paper per hour, while
the card-only machine requires W rolls of paper per hour.
The amusement park needs to be able to process at least U
people per hour but can use at most V paper rolls per hour.
Additionally, the number of card-only machines must not exceed the number of
cash-based machines. The objective is to minimize the total number of machines
in the park.
"""
import json
from gurobipy import *
model = Model()
slack_0 = model.addVar(lb=0, name='slack_0')
slack_2 = model.addVar(lb=0, name='slack_2')
slack_1 = model.addVar(lb=0, name='slack_1')
with open('47/47_c/parameters.json', 'r') as f:
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
model.write('47/47_g/model.lp')
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
with open('47/47_g/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
