# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
Employees have the option of using Car or Bus for transportation. A Car can
carry A employees and produces B units of pollution, while
a Bus can carry C employees and produces D units of
pollution. At least E employees must be transported, and
no more than F Buses can be used. The objective is to minimize the total
pollution produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("183/183_2/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter A @Def: The number of employees that a car can take @Shape: [] 
A = data['A']
# @Parameter B @Def: The pollution produced by a car @Shape: [] 
B = data['B']
# @Parameter C @Def: The number of employees that a bus can take @Shape: [] 
C = data['C']
# @Parameter D @Def: The pollution produced by a bus @Shape: [] 
D = data['D']
# @Parameter E @Def: The minimum number of employees that need to be transported @Shape: [] 
E = data['E']
# @Parameter F @Def: The maximum number of buses that can be used @Shape: [] 
F = data['F']

# Variables 
# @Variable a @Def: The number of cars used for transportation @Shape: ['Integer'] 
a = model.addVar(vtype=GRB.INTEGER, name="a")
# @Variable b @Def: The number of buses used for transportation @Shape: ['Integer'] 
b = model.addVar(vtype=GRB.INTEGER, lb=0, ub=F, name="b")

# Constraints 
# @Constraint Constr_1 @Def: At least E employees must be transported.
model.addConstr(a * A + b * C >= E)
# @Constraint Constr_2 @Def: No more than F buses can be used.


# Objective 
# @Objective Objective @Def: Total pollution produced is the sum of pollution from cars and buses. The objective is to minimize the total pollution produced.
model.setObjective(a * B + b * D, GRB.MINIMIZE)

# Solve 
model.optimize()

# Extract solution 
solution = {}
variables = {}
objective = []
variables['a'] = a.x
variables['b'] = b.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('183/183_2/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
