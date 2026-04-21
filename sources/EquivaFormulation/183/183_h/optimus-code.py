# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Employees have the option of using Car or Bus for transportation. A Car can
carry K employees and produces M units of pollution, while
a Bus can carry D employees and produces O units of
pollution. At least J employees must be transported, and
no more than S Buses can be used. The objective is to minimize the total
pollution produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("183/183_h/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter K @Def: The number of employees that a car can take @Shape: [] 
K = data['K']
# @Parameter M @Def: The pollution produced by a car @Shape: [] 
M = data['M']
# @Parameter D @Def: The number of employees that a bus can take @Shape: [] 
D = data['D']
# @Parameter O @Def: The pollution produced by a bus @Shape: [] 
O = data['O']
# @Parameter J @Def: The minimum number of employees that need to be transported @Shape: [] 
J = data['J']
# @Parameter S @Def: The maximum number of buses that can be used @Shape: [] 
S = data['S']

# Variables 


# @Variable m1 @Def: Part 1 of variable (m1 + m2)@Shape: ['Integer']
m1 = model.addVar(vtype=GRB.INTEGER, name="m1")# @Variable h1 @Def: Part 1 of variable h @Shape: ['Integer']
h1 = model.addVar(vtype=GRB.INTEGER, name="h1")
# @Variable h2 @Def: Part 2 of variable (h1 + h2)@Shape: ['Integer']
h2 = model.addVar(vtype=GRB.INTEGER, name="h2")

# @Variable m2 @Def: Part 2 of variable (m1 + m2)@Shape: ['Integer']
m2 = model.addVar(vtype=GRB.INTEGER, name="m2")

# Constraints 
# @Constraint Constr_1 @Def: At least J employees must be transported.
model.addConstr((m1 + m2)* K + (h1 + h2)* D >= J)
# @Constraint Constr_2 @Def: No more than S buses can be used.


# Objective 
# @Objective Objective @Def: Total pollution produced is the sum of pollution from cars and buses. The objective is to minimize the total pollution produced.
model.setObjective((m1 + m2)* M + (h1 + h2)* O, GRB.MINIMIZE)

# Solve 
model.optimize()
model.write("183/183_h/model.lp")

# Extract solution 
solution = {}
variables = {}
variables['m1'] = m1.X
variables['m2'] = m2.X
variables['h1'] = h1.X
variables['h2'] = h2.X
objective = []
solution['variables'] = variables
solution['objective'] = model.objVal
with open('183/183_h/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
