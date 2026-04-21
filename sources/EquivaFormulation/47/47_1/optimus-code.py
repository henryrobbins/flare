# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
An amusement park is installing cash-based machines and card-only machines. A
cash-based machine can process A people per hour, while
a card-only machine can process B people per hour. The
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
     
# Create a new model
model = Model()

# Load data 
with open("47/47_1/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter A @Def: Processing rate of a cash-based machine in people per hour @Shape: [] 
A = data['A']
# @Parameter B @Def: Processing rate of a card-only machine in people per hour @Shape: [] 
B = data['B']
# @Parameter C @Def: Number of paper rolls used per hour by a cash-based machine @Shape: [] 
C = data['C']
# @Parameter D @Def: Number of paper rolls used per hour by a card-only machine @Shape: [] 
D = data['D']
# @Parameter E @Def: Minimum number of people that must be processed per hour @Shape: [] 
E = data['E']
# @Parameter F @Def: Maximum number of paper rolls that can be used per hour @Shape: [] 
F = data['F']

# Variables 
# @Variable a @Def: The number of cash-based machines @Shape: [] 
a = model.addVar(vtype=GRB.INTEGER, name="a")
# @Variable b @Def: The number of card-only machines @Shape: [] 
b = model.addVar(vtype=GRB.INTEGER, name="b")

# Constraints 
# @Constraint Constr_1 @Def: The total number of people processed per hour by cash-based and card-only machines must be at least E.
model.addConstr(A * a + B * b >= E)
# @Constraint Constr_2 @Def: The total number of paper rolls used per hour by cash-based and card-only machines must not exceed F.
model.addConstr(a * C + b * D <= F)
# @Constraint Constr_3 @Def: The number of card-only machines must not exceed the number of cash-based machines.
model.addConstr(b <= a)

# Objective 
# @Objective Objective @Def: Minimize the total number of machines in the park.
model.setObjective(a + b, GRB.MINIMIZE)

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
with open('47/47_1/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
