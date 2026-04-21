# Code automatically generated from OptiMUS

# Problem type: LP        
# Problem description
'''
A glass factory produces Regular and Tempered glass panes. Producing one Regular
pane requires C time on the heating machine and S time
on the cooling machine. Producing one Tempered pane requires P
time on the heating machine and L time on the cooling machine. The
heating machine is available for a maximum of D per day, and the
cooling machine is available for a maximum of V per day. Each
Regular pane generates a profit of T, and each Tempered pane
generates a profit of H. The factory aims to determine the number
of Regular and Tempered panes to produce in order to maximize total profit.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("92/92_k/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter D @Def: Maximum available time for the heating machine per day @Shape: [] 
D = data['D']
# @Parameter V @Def: Maximum available time for the cooling machine per day @Shape: [] 
V = data['V']
# @Parameter C @Def: Heating time required to produce one regular glass pane @Shape: [] 
C = data['C']
# @Parameter S @Def: Cooling time required to produce one regular glass pane @Shape: [] 
S = data['S']
# @Parameter P @Def: Heating time required to produce one tempered glass pane @Shape: [] 
P = data['P']
# @Parameter L @Def: Cooling time required to produce one tempered glass pane @Shape: [] 
L = data['L']
# @Parameter T @Def: Profit per regular glass pane @Shape: [] 
T = data['T']
# @Parameter H @Def: Profit per tempered glass pane @Shape: [] 
H = data['H']

# Variables 
# @Variable e @Def: The number of regular glass panes to produce @Shape: [] 
e = model.addVar(vtype=GRB.CONTINUOUS, name="e")
# @Variable h @Def: The number of tempered glass panes to produce @Shape: [] 
h = model.addVar(vtype=GRB.CONTINUOUS, name="h")

# Constraints 
# @Constraint Constr_1 @Def: The total heating time required for producing Regular and Tempered panes does not exceed D.
model.addConstr(C * e + P * h <= D, name="HeatingTime")
# @Constraint Constr_2 @Def: The total cooling time required for producing Regular and Tempered panes does not exceed V.
model.addConstr(S * e + L * h <= V)

# Objective 
# @Objective Objective @Def: Total profit is T multiplied by the number of Regular panes plus H multiplied by the number of Tempered panes. The objective is to maximize the total profit.
model.setObjective(45.0, GRB.MAXIMIZE)
# Solve 
model.optimize()
model.write("92/92_k/model.lp")

# Extract solution 
solution = {}
variables = {}
objective = []
variables['e'] = e.x
variables['h'] = h.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('92/92_k/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
