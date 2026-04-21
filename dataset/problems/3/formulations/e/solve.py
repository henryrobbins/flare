"""
The summer camp uses N different types of beakers. Each beaker type i
consumes T[i] units of flour and
V[i] units of special liquid to produce
X[i] units of slime and C[i] units of
waste. The camp has D units of flour and Z
units of special liquid available. The total waste produced must not exceed
E. The goal is to determine how many beakers of each type to use
to maximize the total amount of slime produced.
"""
import json
from gurobipy import *
model = Model()

with open('92/92_c/parameters.json', 'r') as f:
    data = json.load(f)
N = data['N']
D = data['D']
Z = data['Z']
E = data['E']
T = data['T']
V = data['V']
X = data['X']
C = data['C']
n = model.addVars(N, vtype=GRB.CONTINUOUS, name='n')
model.addConstr(quicksum(n[i] for i in range(N)) <= D)
model.addConstr(quicksum(V[i] * n[i] for i in range(N)) <= Z)
model.addConstr(quicksum(C[i] * n[i] for i in range(N)) <= E)
model.setObjective(quicksum(X[i] * n[i] for i in range(N)), GRB.MAXIMIZE)
model.optimize()
model.write('92/92_g/model.lp')
solution = {}
variables = {}

objective = []
variables['n'] = {i: n[i].X for i in range(N)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('92/92_g/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
