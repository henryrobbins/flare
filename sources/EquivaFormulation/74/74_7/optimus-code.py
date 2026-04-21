"""
A scientist is conducting A different experiments to produce
electricity. Each experiment i produces E[i] units of
electricity and requires specific amounts of B types of resources as
defined by D[j][i]. The laboratory has C[j] units
of each resource available. The scientist aims to determine the number of each
experiment to conduct in order to maximize the total electricity produced.
"""
import json
from gurobipy import *
model = Model()

with open('74/74_0/parameters.json', 'r') as f:
    data = json.load(f)
A = data['A']
B = data['B']
C = data['C']
D = data['D']
E = data['E']
a = model.addVars(A, vtype=GRB.CONTINUOUS, name='a')
model.addConstr(quicksum(D[0][i] * a[i] for i in range(A)) <= C[0])
model.addConstr(quicksum(D[1][i] * a[i] for i in range(A)) <= C[1])
model.setObjective(quicksum(a[i] * E[i] for i in range(A)), GRB.MAXIMIZE)
model.optimize()
solution = {}
variables = {}

objective = []
variables['a'] = {i: a[i].X for i in range(A)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('74/74_7/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
