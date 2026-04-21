"""
An amusement park is installing cash-based machines and card-only machines. A
cash-based machine can process A people per hour, while
a card-only machine can process B people per hour. The
cash-based machine needs C rolls of paper per hour, while
the card-only machine requires D rolls of paper per hour.
The amusement park needs to be able to process at least E
people per hour but can use at most F paper rolls per hour.
Additionally, the number of card-only machines must not exceed the number of
cash-based machines. The objective is to minimize the total number of machines
in the park.
"""
import json
from gurobipy import *
model = Model()
slack_0 = model.addVar(lb=0, name='slack_0')
slack_1 = model.addVar(lb=0, name='slack_1')
slack_2 = model.addVar(lb=0, name='slack_2')
with open('47/47_0/parameters.json', 'r') as f:
    data = json.load(f)
A = data['A']
B = data['B']
C = data['C']
D = data['D']
E = data['E']
F = data['F']
a = model.addVar(vtype=GRB.INTEGER, name='a')
b = model.addVar(vtype=GRB.INTEGER, name='b')
model.addConstr(A * a + B * b - slack_0 == E)
model.addConstr(a * C + b * D + slack_1 == F)
model.addConstr(b + slack_2 == a)
model.setObjective(a + b, GRB.MINIMIZE)
model.optimize()
solution = {}
variables = {}
variables['slack_0'] = slack_0.X
variables['slack_1'] = slack_1.X
variables['slack_2'] = slack_2.X
objective = []
variables['a'] = a.x
variables['b'] = b.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('47/47_7/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
