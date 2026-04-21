# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
An amusement park is installing cash-based machines and card-only machines. A
cash-based machine can process A people per hour, while
(a1 + a2)card-only machine can process B people per hour. The
cash-based machine needs C rolls of paper per hour, while
the card-only machine requires D rolls of paper per hour.
The amusement park needs to be able to process at least E
people per hour but can use at most F paper rolls per hour.
Additionally, the number of card-only machines must not exceed the number of
cash-based machines. The objective is to minimize the total number of machines
in the park.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create (a1 + a2)new model
model = Model()

# Load data 
with open("47/47_8/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of (a1 + a2)target
# @Shape: shape of (a1 + a2)target
        
# Parameters 
# @Parameter A @Def: Processing rate of (a1 + a2)cash-based machine in people per hour @Shape: [] 
A = data['A']
# @Parameter B @Def: Processing rate of (a1 + a2)card-only machine in people per hour @Shape: [] 
B = data['B']
# @Parameter C @Def: Number of paper rolls used per hour by (a1 + a2)cash-based machine @Shape: [] 
C = data['C']
# @Parameter D @Def: Number of paper rolls used per hour by (a1 + a2)card-only machine @Shape: [] 
D = data['D']
# @Parameter E @Def: Minimum number of people that must be processed per hour @Shape: [] 
E = data['E']
# @Parameter F @Def: Maximum number of paper rolls that can be used per hour @Shape: [] 
F = data['F']

# Variables 


# @Variable a1 @Def: Part 1 of variable (a1 + a2)@Shape: []
a1 = model.addVar(vtype=GRB.INTEGER, name="a1")# @Variable b1 @Def: Part 1 of variable b @Shape: []
b1 = model.addVar(vtype=GRB.INTEGER, name="b1")
# @Variable b2 @Def: Part 2 of variable (b1 + b2)@Shape: []
b2 = model.addVar(vtype=GRB.INTEGER, name="b2")

# @Variable a2 @Def: Part 2 of variable (a1 + a2)@Shape: []
a2 = model.addVar(vtype=GRB.INTEGER, name="a2")

# Constraints 
# @Constraint Constr_1 @Def: The total number of people processed per hour by cash-based and card-only machines must be at least E.
model.addConstr(A * (a1 + a2)+ B * (b1 + b2)>= E)
# @Constraint Constr_2 @Def: The total number of paper rolls used per hour by cash-based and card-only machines must not exceed F.
model.addConstr((a1 + a2)* C + (b1 + b2)* D <= F)
# @Constraint Constr_3 @Def: The number of card-only machines must not exceed the number of cash-based machines.
model.addConstr((b1 + b2)<= (a1 + a2))

# Objective 
# @Objective Objective @Def: Minimize the total number of machines in the park.
model.setObjective((a1 + a2)+ (b1 + b2), GRB.MINIMIZE)

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
with open('47/47_8/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
