"""
A scientist is conducting M different experiments to produce
electricity. Each experiment i produces A[i] units of
electricity and requires specific amounts of N types of resources as
defined by I[j][i]. The laboratory has Y[j] units
of each resource available. The scientist aims to determine the number of each
experiment to conduct in order to maximize the total electricity produced.
"""
import json
from gurobipy import *
model = Model()

with open('74/74_c/parameters.json', 'r') as f:
    data = json.load(f)
M = data['M']
N = data['N']
Y = data['Y']
I = data['I']
A = data['A']
j = model.addVars(M, vtype=GRB.CONTINUOUS, name='j')
model.addConstr(quicksum(I[0][i] * j[i] for i in range(M)) <= Y[0])
model.addConstr(quicksum(I[1][i] * j[i] for i in range(M)) <= Y[1])
model.setObjective(quicksum(j[i] * A[i] for i in range(M)), GRB.MAXIMIZE)
model.optimize()
model.write('74/74_g/model.lp')
solution = {}
variables = {}

objective = []
variables['j'] = {i: j[i].X for i in range(M)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('74/74_g/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
