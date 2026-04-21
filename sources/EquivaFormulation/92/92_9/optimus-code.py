"""
The summer camp uses A different types of beakers. Each beaker type i
consumes E[i] units of flour and
F[i] units of special liquid to produce
G[i] units of slime and H[i] units of
waste. The camp has B units of flour and C
units of special liquid available. The total waste produced must not exceed
D. The goal is to determine how many beakers of each type to use
to maximize the total amount of slime produced.
"""
import json
from gurobipy import *
model = Model()

with open('92/92_0/parameters.json', 'r') as f:
    data = json.load(f)
A = data['A']
B = data['B']
C = data['C']
D = data['D']
E = data['E']
F = data['F']
G = data['G']
H = data['H']
a = model.addVars(A, vtype=GRB.CONTINUOUS, name='a')
model.addConstr(quicksum(a[i] for i in range(A)) <= B)
model.addConstr(quicksum(F[i] * a[i] for i in range(A)) <= C)
model.addConstr(quicksum(H[i] * a[i] for i in range(A)) <= D)
model.setObjective(quicksum(G[i] * a[i] for i in range(A)), GRB.MAXIMIZE)
model.optimize()
solution = {}
variables = {}

objective = []
variables['a'] = {i: a[i].X for i in range(A)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('92/92_9/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
