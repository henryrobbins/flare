# Code automatically generated from OptiMUS

# Problem type: LP        
# Problem description
'''
The summer camp uses N different types of beakers. Each beaker type i
consumes T[i] units of flour and
V[i] units of special liquid to produce
X[i] units of slime and C[i] units of
waste. The camp has D units of flour and Z
units of special liquid available. The total waste produced must not exceed
E. The goal is to determine how many beakers of each type to use
to maximize the total amount of slime produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("92/92_f/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target        
        
# Parameters 
# @Parameter N @Def: Number of beakers @Shape: [] 
N = data['N']
# @Parameter D @Def: Amount of flour available @Shape: [] 
D = data['D']
# @Parameter Z @Def: Amount of special liquid available @Shape: [] 
Z = data['Z']
# @Parameter E @Def: Maximum amount of waste allowed @Shape: [] 
E = data['E']
# @Parameter T @Def: Amount of flour used by each beaker @Shape: ['N'] 
T = data['T']
# @Parameter V @Def: Amount of special liquid used by each beaker @Shape: ['N'] 
V = data['V']
# @Parameter X @Def: Amount of slime produced by each beaker @Shape: ['N'] 
X = data['X']
# @Parameter C @Def: Amount of waste produced by each beaker @Shape: ['N'] 
C = data['C']

# Variables 
# @Variable n @Def: The amount of flour used by beaker i @Shape: ['N'] 
n = model.addVars(N, vtype=GRB.CONTINUOUS, name="n")


# @Variable zed @Def: New variable representing the objective function @Shape: []
zed = model.addVar(vtype=GRB.CONTINUOUS, name="zed")
# Constraints 
# @Constraint Constr_1 @Def: The total amount of flour used by all beakers does not exceed D.
model.addConstr(quicksum(n[i] for i in range(N)) <= D)
# @Constraint Constr_2 @Def: The total amount of special liquid used by all beakers does not exceed Z.
model.addConstr(quicksum(V[i] * n[i] for i in range(N)) <= Z)
# @Constraint Constr_3 @Def: The total amount of waste produced by all beakers does not exceed E.
model.addConstr(quicksum(C[i] * n[i] for i in range(N)) <= E)


# Constraint defining zed in terms of original variables
model.addConstr(zed == quicksum(X[i] * n[i] for i in range(N)))
# Objective 
# @Objective Objective @Def: The total amount of slime produced by all beakers is maximized.
model.setObjective(zed, GRB.MAXIMIZE)

# Solve 
model.optimize()
model.write("92/92_f/model.lp")

# Extract solution 
solution = {}
variables = {}
variables['zed'] = zed.x
objective = []
variables['n'] = {i: n[i].X for i in range(N)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('92/92_f/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)