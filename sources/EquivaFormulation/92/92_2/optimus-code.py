# Code automatically generated from OptiMUS

# Problem type: LP        
# Problem description
'''
The summer camp uses A different types of beakers. Each beaker type i
consumes E[i] units of flour and
F[i] units of special liquid to produce
G[i] units of slime and H[i] units of
waste. The camp has B units of flour and C
units of special liquid available. The total waste produced must not exceed
D. The goal is to determine how many beakers of each type to use
to maximize the total amount of slime produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("92/92_2/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target        
        
# Parameters 
# @Parameter A @Def: Number of beakers @Shape: [] 
A = data['A']
# @Parameter B @Def: Amount of flour available @Shape: [] 
B = data['B']
# @Parameter C @Def: Amount of special liquid available @Shape: [] 
C = data['C']
# @Parameter D @Def: Maximum amount of waste allowed @Shape: [] 
D = data['D']
# @Parameter E @Def: Amount of flour used by each beaker @Shape: ['A'] 
E = data['E']
# @Parameter F @Def: Amount of special liquid used by each beaker @Shape: ['A'] 
F = data['F']
# @Parameter G @Def: Amount of slime produced by each beaker @Shape: ['A'] 
G = data['G']
# @Parameter H @Def: Amount of waste produced by each beaker @Shape: ['A'] 
H = data['H']

# Variables 
# @Variable a @Def: The amount of flour used by beaker i (10 times before) @Shape: ['A'] 
a = model.addVars(A, vtype=GRB.CONTINUOUS, name="a")

# Constraints 
# @Constraint Constr_1 @Def: The total amount of flour used by all beakers does not exceed B.
model.addConstr(quicksum((1/10) * a[i] for i in range(A)) <= B)
# @Constraint Constr_2 @Def: The total amount of special liquid used by all beakers does not exceed C.
model.addConstr(quicksum(F[i] * (1/10) * a[i] for i in range(A)) <= C)
# @Constraint Constr_3 @Def: The total amount of waste produced by all beakers does not exceed D.
model.addConstr(quicksum(H[i] * (1/10) * a[i] for i in range(A)) <= D)

# Objective 
# @Objective Objective @Def: The total amount of slime produced by all beakers is maximized.
model.setObjective(quicksum(G[i] * (1/10) * a[i] for i in range(A)), GRB.MAXIMIZE)

# Solve 
model.optimize()

# Extract solution 
solution = {}
variables = {}
objective = []
variables['a'] = {i: a[i].X for i in range(A)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('92/92_2/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)