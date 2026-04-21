# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
An oil and gas company sends oil to the port using containers and trucks. Each
container can hold G units of oil while each truck can hold
Y units of oil. Due to government restrictions, the number of trucks
used must be at most K multiplied by the number of
containers used. If at least V units of oil need to be sent to the
port and at least L containers must be used, minimize the total
number of containers and trucks needed.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("47/47_j/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter G @Def: Number of units of oil each container can hold @Shape: [] 
G = data['G']
# @Parameter Y @Def: Number of units of oil each truck can hold @Shape: [] 
Y = data['Y']
# @Parameter K @Def: Maximum allowed ratio of number of trucks to number of containers @Shape: [] 
K = data['K']
# @Parameter V @Def: Minimum number of units of oil that need to be sent to the port @Shape: [] 
V = data['V']
# @Parameter L @Def: Minimum number of containers that need to be used @Shape: [] 
L = data['L']

# Variables 
# @Variable c @Def: The number of containers used @Shape: [] 
c = model.addVar(vtype=GRB.INTEGER, name="c", lb=L)
# @Variable p @Def: The number of trucks used @Shape: [] 
p = model.addVar(vtype=GRB.INTEGER, name="p")

# Constraints 
# @Constraint Constr_1 @Def: The total amount of oil sent to the port must be at least 2000 units, calculated as 30 units per container plus 40 units per truck.
model.addConstr(G * c + Y * p >= V)
# @Constraint Constr_2 @Def: The number of trucks used must be at most half the number of containers used.
model.addConstr(p <= K * c)
# @Constraint Constr_3 @Def: At least 15 containers must be used.
model.addConstr(c >= L)

# Objective 
# @Objective Objective @Def: The objective is to minimize the total number of containers and trucks needed.
model.setObjective(c + p, GRB.MINIMIZE)

# Solve 
model.optimize()
model.write("47/47_j/model.lp")

# Extract solution 
solution = {}
variables = {}
objective = []
variables['c'] = c.x
variables['p'] = p.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('47/47_j/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
