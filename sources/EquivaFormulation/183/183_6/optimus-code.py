# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Employees have the option of using Car or Bus for transportation. A Car can
carry A employees and produces B units of pollution, while
(a1 + a2)Bus can carry C employees and produces D units of
pollution. At least E employees must be transported, and
no more than F Buses can be used. The objective is to minimize the total
pollution produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create (a1 + a2)new model
model = Model()

# Load data 
with open("183/183_6/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of (a1 + a2)target
# @Shape: shape of (a1 + a2)target
        
# Parameters 
# @Parameter A @Def: The number of employees that (a1 + a2)car can take @Shape: [] 
A = data['A']
# @Parameter B @Def: The pollution produced by (a1 + a2)car @Shape: [] 
B = data['B']
# @Parameter C @Def: The number of employees that (a1 + a2)bus can take @Shape: [] 
C = data['C']
# @Parameter D @Def: The pollution produced by (a1 + a2)bus @Shape: [] 
D = data['D']
# @Parameter E @Def: The minimum number of employees that need to be transported @Shape: [] 
E = data['E']
# @Parameter F @Def: The maximum number of buses that can be used @Shape: [] 
F = data['F']

# Variables 


# @Variable a1 @Def: Part 1 of variable (a1 + a2)@Shape: ['Integer']
a1 = model.addVar(vtype=GRB.INTEGER, name="a1")# @Variable b1 @Def: Part 1 of variable b @Shape: ['Integer']
b1 = model.addVar(vtype=GRB.INTEGER, name="b1")
# @Variable b2 @Def: Part 2 of variable (b1 + b2)@Shape: ['Integer']
b2 = model.addVar(vtype=GRB.INTEGER, name="b2")

# @Variable a2 @Def: Part 2 of variable (a1 + a2)@Shape: ['Integer']
a2 = model.addVar(vtype=GRB.INTEGER, name="a2")

# Constraints 
# @Constraint Constr_1 @Def: At least E employees must be transported.
model.addConstr((a1 + a2)* A + (b1 + b2)* C >= E)
# @Constraint Constr_2 @Def: No more than F buses can be used.


# Objective 
# @Objective Objective @Def: Total pollution produced is the sum of pollution from cars and buses. The objective is to minimize the total pollution produced.
model.setObjective((a1 + a2)* B + (b1 + b2)* D, GRB.MINIMIZE)

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
with open('183/183_6/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
