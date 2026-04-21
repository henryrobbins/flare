"""
Employees have the option of using Car or Bus for transportation. A Car can
carry A employees and produces B units of pollution, while
a Bus can carry C employees and produces D units of
pollution. At least E employees must be transported, and
no more than F Buses can be used. The objective is to minimize the total
pollution produced.
"""
import json
from gurobipy import *
model = Model()
slack_0 = model.addVar(lb=0, name='slack_0')
with open('183/183_0/parameters.json', 'r') as f:
    data = json.load(f)
A = data['A']
B = data['B']
C = data['C']
D = data['D']
E = data['E']
F = data['F']
a = model.addVar(vtype=GRB.INTEGER, name='a')
b = model.addVar(vtype=GRB.INTEGER, lb=0, ub=F, name='b')
model.addConstr(a * A + b * C - slack_0 == E)
model.setObjective(a * B + b * D, GRB.MINIMIZE)
model.optimize()
solution = {}
variables = {}
variables['slack_0'] = slack_0.X
objective = []
variables['a'] = a.x
variables['b'] = b.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('183/183_9/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
