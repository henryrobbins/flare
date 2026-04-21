# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Both subsoil and topsoil need to be added to a garden bed. The objective is to
minimize the total amount of water required to hydrate the garden bed, where
each bag of subsoil requires Z units of water per day and each bag of
topsoil requires B units of water per day. The total number of bags
of subsoil and topsoil combined must not exceed D. Additionally, at
least P bags of topsoil must be used, and the proportion of topsoil
bags must not exceed K of all bags.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("217/217_h/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter Z @Def: Amount of water required to hydrate one bag of subsoil per day @Shape: [] 
Z = data['Z']
# @Parameter B @Def: Amount of water required to hydrate one bag of topsoil per day @Shape: [] 
B = data['B']
# @Parameter D @Def: Maximum number of bags of topsoil and subsoil combined @Shape: [] 
D = data['D']
# @Parameter P @Def: Minimum number of topsoil bags to be used @Shape: [] 
P = data['P']
# @Parameter K @Def: Maximum proportion of bags that can be topsoil @Shape: [] 
K = data['K']

# Variables 


# @Variable h1 @Def: Part 1 of variable (h1 + h2)@Shape: []
h1 = model.addVar(vtype=GRB.INTEGER, name="h1")# @Variable d1 @Def: Part 1 of variable d @Shape: []
d1 = model.addVar(vtype=GRB.INTEGER, name="d1")
# @Variable d2 @Def: Part 2 of variable (d1 + d2)@Shape: []
d2 = model.addVar(vtype=GRB.INTEGER, name="d2")

# @Variable h2 @Def: Part 2 of variable (h1 + h2)@Shape: []
h2 = model.addVar(vtype=GRB.INTEGER, name="h2")

# Constraints 
# @Constraint Constr_1 @Def: The total number of subsoil and topsoil bags combined must not exceed D.
model.addConstr((h1 + h2)+ (d1 + d2)<= D)
# @Constraint Constr_2 @Def: At least P bags of topsoil must be used.
model.addConstr((d1 + d2)>= P)
# @Constraint Constr_3 @Def: The proportion of topsoil bags must not exceed K of all bags.
model.addConstr((d1 + d2)<= K * ((d1 + d2)+ (h1 + h2)))

# Objective 
# @Objective Objective @Def: Total water required is the sum of (Z * number of subsoil bags) and (B * number of topsoil bags). The objective is to minimize the total water required.
model.setObjective(Z * (h1 + h2)+ B * (d1 + d2), GRB.MINIMIZE)

# Solve 
model.optimize()
model.write("217/217_h/model.lp")

# Extract solution 
solution = {}
variables = {}
variables['h1'] = h1.X
variables['h2'] = h2.X
variables['d1'] = d1.X
variables['d2'] = d2.X
objective = []
solution['variables'] = variables
solution['objective'] = model.objVal
with open('217/217_h/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
