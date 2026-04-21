# Code automatically generated from OptiMUS

# Problem type: MIP        
# Problem description
'''
A village delivers mail to nearby villages either by runners or canoeers.
Runners can carry V bags of mail each trip and take U
hours. Canoeers can carry Z bags of mail each trip and take
N hours. At most P of deliveries can be made by canoe.
Additionally, the village can spare at most C total hours for
deliveries and must use at least E runners. The objective is to
determine the number of trips by runners and canoeers to maximize the total
amount of mail delivered.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("183/183_k/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target
        
# Parameters 
# @Parameter V @Def: Number of bags a runner can carry each trip @Shape: [] 
V = data['V']
# @Parameter U @Def: Time a runner takes per trip (in hours) @Shape: [] 
U = data['U']
# @Parameter Z @Def: Number of bags a canoeer can carry each trip @Shape: [] 
Z = data['Z']
# @Parameter N @Def: Time a canoeer takes per trip (in hours) @Shape: [] 
N = data['N']
# @Parameter P @Def: Maximum fraction of total deliveries that can be made by canoe @Shape: [] 
P = data['P']
# @Parameter C @Def: Maximum total hours the village can spare for deliveries @Shape: [] 
C = data['C']
# @Parameter E @Def: Minimum number of runners that must be used @Shape: [] 
E = data['E']

# Variables 
# @Variable a @Def: Number of trips made by runners @Shape: ['Integer'] 
a = model.addVar(vtype=GRB.INTEGER, name="a")
# @Variable p @Def: Number of trips made by canoeers @Shape: ['Integer'] 
p = model.addVar(vtype=GRB.INTEGER, name="p")
# @Variable e @Def: The number of runners used for deliveries @Shape: ['Integer'] 
e = model.addVar(vtype=GRB.INTEGER, lb=E, name="e")

# Constraints 
# @Constraint Constr_1 @Def: The total hours spent on deliveries by runners and canoeers must not exceed C.
model.addConstr(U * a + N * p <= C)
# @Constraint Constr_2 @Def: No more than P of the total mail delivered can be delivered by canoeers.
model.addConstr(p * Z <= P * (a * V + p * Z))
# @Constraint Constr_3 @Def: At least E runners must be used for deliveries.
model.addConstr(e >= E)

# Objective 
# @Objective Objective @Def: Maximize the total amount of mail delivered by runners and canoeers within the given time, capacity, and usage constraints.
model.setObjective(670.0, GRB.MAXIMIZE)
# Solve 
model.optimize()
model.write("183/183_k/model.lp")

# Extract solution 
solution = {}
variables = {}
objective = []
variables['a'] = a.x
variables['p'] = p.x
variables['e'] = e.x
solution['variables'] = variables
solution['objective'] = model.objVal
with open('183/183_k/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
