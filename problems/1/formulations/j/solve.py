# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
An amusement park is installing cash-based machines and card-only machines. A
cash-based machine can process A people per hour, while
a card-only machine can process K people per hour. The
cash-based machine needs Y rolls of paper per hour, while
the card-only machine requires W rolls of paper per hour.
The amusement park needs to be able to process at least U
people per hour but can use at most V paper rolls per hour.
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
with open("47/47_l/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter A @Def: Processing rate of a cash-based machine in people per hour @Shape: [] 
A = data['A']
# @Parameter K @Def: Processing rate of a card-only machine in people per hour @Shape: [] 
K = data['K']
# @Parameter Y @Def: Number of paper rolls used per hour by a cash-based machine @Shape: [] 
Y = data['Y']
# @Parameter W @Def: Number of paper rolls used per hour by a card-only machine @Shape: [] 
W = data['W']
# @Parameter U @Def: Minimum number of people that must be processed per hour @Shape: [] 
U = data['U']
# @Parameter V @Def: Maximum number of paper rolls that can be used per hour @Shape: [] 
V = data['V']

# Variables 
# @Variable s @Def: The number of cash-based machines @Shape: [] 
s = model.addVar(vtype=GRB.INTEGER, name="s")
# @Variable r @Def: The number of card-only machines @Shape: [] 
r = model.addVar(vtype=GRB.INTEGER, name="r")

# Constraints 
# @Constraint Constr_1 @Def: The total number of people processed per hour by cash-based and card-only machines must be at least U.
# @Constraint Constr_2 @Def: The total number of paper rolls used per hour by cash-based and card-only machines must not exceed V.
model.addConstr(s * Y + r * W <= V)
# @Constraint Constr_3 @Def: The number of card-only machines must not exceed the number of cash-based machines.

# Objective 
# @Objective Objective @Def: Minimize the total number of machines in the park.
model.setObjective(s + r, GRB.MINIMIZE)

# Solve 
model.optimize()
model.write("47/47_l/model.lp")

# Extract solution 
solution = {}
variables = {}
objective = []
variables['s'] = s.x
variables['r'] = r.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('47/47_l/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
