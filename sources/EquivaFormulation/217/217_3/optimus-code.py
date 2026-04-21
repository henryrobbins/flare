# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Both subsoil and topsoil need to be added to a garden bed. The objective is to
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
     
# Create a new model
model = Model()

# Load data 
with open("217/217_3/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
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
# @Variable a @Def: The number of subsoil bags @Shape: [] 
a = model.addVar(vtype=GRB.INTEGER, name="a")
# @Variable b @Def: The number of topsoil bags @Shape: [] 
b = model.addVar(vtype=GRB.INTEGER, name="b")


# Variable z representing the objective function
z = model.addVar(vtype=GRB.CONTINUOUS, name="z")
# Constraints 
# @Constraint Constr_1 @Def: The total number of subsoil and topsoil bags combined must not exceed C.
model.addConstr(a + b <= C)
# @Constraint Constr_2 @Def: At least D bags of topsoil must be used.
model.addConstr(b >= D)
# @Constraint Constr_3 @Def: The proportion of topsoil bags must not exceed E of all bags.
model.addConstr(b <= E * (b + a))


# Constraint defining z
model.addConstr(z == A * a + B * b)
# Objective 
# @Objective Objective @Def: Total water required is the sum of (A * number of subsoil bags) and (B * number of topsoil bags). The objective is to minimize the total water required.
model.setObjective(z, GRB.MINIMIZE)

# Solve 
model.optimize()

# Extract solution 
solution = {}
variables = {}
variables['z'] = z.x
objective = []
variables['a'] = a.x
variables['b'] = b.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('217/217_3/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
