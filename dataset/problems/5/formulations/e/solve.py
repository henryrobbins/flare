"""
Both subsoil and topsoil need to be added to a garden bed. The objective is to
minimize the total amount of water required to hydrate the garden bed, where
each bag of subsoil requires Z units of water per day and each bag of
topsoil requires B units of water per day. The total number of bags
of subsoil and topsoil combined must not exceed D. Additionally, at
least P bags of topsoil must be used, and the proportion of topsoil
bags must not exceed K of all bags.
"""
import json
from gurobipy import *
model = Model()
slack_1 = model.addVar(lb=0, name='slack_1')
slack_2 = model.addVar(lb=0, name='slack_2')
slack_0 = model.addVar(lb=0, name='slack_0')
with open('217/217_c/parameters.json', 'r') as f:
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
model.write('217/217_g/model.lp')
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
with open('217/217_g/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
