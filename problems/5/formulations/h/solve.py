# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
A vine company sells two types of bottles: vintage and regular. A vintage bottle
holds D milliliters of vine, while a regular bottle holds
J milliliters of vine. The company has A
milliliters of vine available. The number of regular bottles must be at least
O times the number of vintage bottles. Additionally, at
least Q vintage bottles must be produced. The objective is to
maximize the total number of bottles produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("217/217_j/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter D @Def: Capacity of a vintage bottle in milliliters @Shape: [] 
D = data['D']
# @Parameter J @Def: Capacity of a regular bottle in milliliters @Shape: [] 
J = data['J']
# @Parameter A @Def: Total available vine in milliliters @Shape: [] 
A = data['A']
# @Parameter O @Def: Minimum ratio of regular bottles to vintage bottles @Shape: [] 
O = data['O']
# @Parameter Q @Def: Minimum number of vintage bottles to be produced @Shape: [] 
Q = data['Q']

# Variables 
# @Variable g @Def: The number of vintage bottles to produce @Shape: [] 
g = model.addVar(vtype=GRB.INTEGER, lb=Q, name="g")
# @Variable z @Def: The number of regular bottles to produce @Shape: [] 
z = model.addVar(vtype=GRB.INTEGER, name="z")

# Constraints 
# @Constraint Constr_1 @Def: The total amount of vine used by vintage and regular bottles must not exceed A milliliters.
model.addConstr(D * g + J * z <= A)
# @Constraint Constr_2 @Def: The number of regular bottles must be at least O times the number of vintage bottles.
model.addConstr(z >= O * g)
# @Constraint Constr_3 @Def: At least Q vintage bottles must be produced.
model.addConstr(g >= Q)

# Objective 
# @Objective Objective @Def: Maximize the total number of bottles produced.
model.setObjective(g + z, GRB.MAXIMIZE)

# Solve 
model.optimize()
model.write("217/217_j/model.lp")

# Extract solution 
solution = {}
variables = {}
objective = []
variables['g'] = g.x
variables['z'] = z.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('217/217_j/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
