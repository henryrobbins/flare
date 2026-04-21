"""
Employees have the option of using Car or Bus for transportation. A Car can
carry K employees and produces M units of pollution, while
a Bus can carry D employees and produces O units of
pollution. At least J employees must be transported, and
no more than S Buses can be used. The objective is to minimize the total
pollution produced.
"""
import json
from gurobipy import *
model = Model()
slack_0 = model.addVar(lb=0, name='slack_0')
with open('183/183_c/parameters.json', 'r') as f:
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
model.write('183/183_g/model.lp')
solution = {}
variables = {}
variables['slack_0'] = slack_0.X
objective = []
variables['m'] = m.x
variables['h'] = h.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('183/183_g/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
