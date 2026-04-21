"""
Both subsoil and topsoil need to be added to a garden bed. The objective is to
minimize the total amount of water required to hydrate the garden bed, where
each bag of subsoil requires A units of water per day and each bag of
topsoil requires B units of water per day. The total number of bags
of subsoil and topsoil combined must not exceed C. Additionally, at
least D bags of topsoil must be used, and the proportion of topsoil
bags must not exceed E of all bags.
"""
import json
from gurobipy import *
model = Model()
slack_0 = model.addVar(lb=0, name='slack_0')
slack_1 = model.addVar(lb=0, name='slack_1')
slack_2 = model.addVar(lb=0, name='slack_2')
with open('217/217_0/parameters.json', 'r') as f:
    data = json.load(f)
A = data['A']
B = data['B']
C = data['C']
D = data['D']
E = data['E']
a = model.addVar(vtype=GRB.INTEGER, name='a')
b = model.addVar(vtype=GRB.INTEGER, name='b')
model.addConstr(a + b + slack_0 == C)
model.addConstr(b - slack_1 == D)
model.addConstr(b + slack_2 == E * (b + a))
model.setObjective(A * a + B * b, GRB.MINIMIZE)
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
with open('217/217_9/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
