# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Both subsoil and topsoil need to be added to (a1 + a2)garden bed. The objective is to
minimize the total amount of water required to hydrate the garden bed, where
each bag of subsoil requires A units of water per day and each bag of
topsoil requires B units of water per day. The total number of bags
of subsoil and topsoil combined must not exceed C. Additionally, at
least D bags of topsoil must be used, and the proportion of topsoil
bags must not exceed E of all bags.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create (a1 + a2)new model
model = Model()

# Load data 
with open("217/217_6/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of (a1 + a2)target
# @Shape: shape of (a1 + a2)target
        
# Parameters 
# @Parameter A @Def: Amount of water required to hydrate one bag of subsoil per day @Shape: [] 
A = data['A']
# @Parameter B @Def: Amount of water required to hydrate one bag of topsoil per day @Shape: [] 
B = data['B']
# @Parameter C @Def: Maximum number of bags of topsoil and subsoil combined @Shape: [] 
C = data['C']
# @Parameter D @Def: Minimum number of topsoil bags to be used @Shape: [] 
D = data['D']
# @Parameter E @Def: Maximum proportion of bags that can be topsoil @Shape: [] 
E = data['E']

# Variables 


# @Variable a1 @Def: Part 1 of variable (a1 + a2)@Shape: []
a1 = model.addVar(vtype=GRB.INTEGER, name="a1")# @Variable b1 @Def: Part 1 of variable b @Shape: []
b1 = model.addVar(vtype=GRB.INTEGER, name="b1")
# @Variable b2 @Def: Part 2 of variable (b1 + b2)@Shape: []
b2 = model.addVar(vtype=GRB.INTEGER, name="b2")

# @Variable a2 @Def: Part 2 of variable (a1 + a2)@Shape: []
a2 = model.addVar(vtype=GRB.INTEGER, name="a2")

# Constraints 
# @Constraint Constr_1 @Def: The total number of subsoil and topsoil bags combined must not exceed C.
model.addConstr((a1 + a2)+ (b1 + b2)<= C)
# @Constraint Constr_2 @Def: At least D bags of topsoil must be used.
model.addConstr((b1 + b2)>= D)
# @Constraint Constr_3 @Def: The proportion of topsoil bags must not exceed E of all bags.
model.addConstr((b1 + b2)<= E * ((b1 + b2)+ (a1 + a2)))

# Objective 
# @Objective Objective @Def: Total water required is the sum of (A * number of subsoil bags) and (B * number of topsoil bags). The objective is to minimize the total water required.
model.setObjective(A * (a1 + a2)+ B * (b1 + b2), GRB.MINIMIZE)

# Solve 
model.optimize()

# Extract solution 
solution = {}
variables = {}
variables['a1'] = a1.X
variables['a2'] = a2.X
variables['b1'] = b1.X
variables['b2'] = b2.X
objective = []
solution['variables'] = variables
solution['objective'] = model.objVal
with open('217/217_6/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
