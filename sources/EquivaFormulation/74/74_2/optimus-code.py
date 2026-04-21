# Code automatically generated from OptiMUS

# Problem type: LP        
# Problem description
'''
A scientist is conducting A different experiments to produce
electricity. Each experiment i produces E[i] units of
electricity and requires specific amounts of B types of resources as
defined by D[j][i]. The laboratory has C[j] units
of each resource available. The scientist aims to determine the number of each
experiment to conduct in order to maximize the total electricity produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("74/74_2/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target            
        
# Parameters 
# @Parameter A @Def: Number of experiments @Shape: [] 
A = data['A']
# @Parameter B @Def: Number of resource types @Shape: [] 
B = data['B']
# @Parameter C @Def: Amount of resource j available @Shape: ['B'] 
C = data['C']
# @Parameter D @Def: Amount of resource j required for experiment i @Shape: ['B', 'A'] 
D = data['D']
# @Parameter E @Def: Amount of electricity produced by experiment i @Shape: ['A'] 
E = data['E']

# Variables 
# @Variable a @Def: The number of times each experiment is conducted (10 times before) @Shape: ['A'] 
a = model.addVars(A, vtype=GRB.CONTINUOUS, name="a")

# Constraints 
# @Constraint Constr_1 @Def: The total metal required for all experiments does not exceed the available metal.
model.addConstr(quicksum(D[0][i] * (1/10) * a[i] for i in range(A)) <= C[0])
# @Constraint Constr_2 @Def: The total acid required for all experiments does not exceed the available acid.
model.addConstr(quicksum(D[1][i] * (1/10) * a[i] for i in range(A)) <= C[1])

# Objective 
# @Objective Objective @Def: Maximize the total electricity produced by conducting the experiments.
model.setObjective(quicksum((1/10) * a[i] * E[i] for i in range(A)), GRB.MAXIMIZE)

# Solve 
model.optimize()

# Extract solution 
solution = {}
variables = {}
objective = []
variables['a'] = {i: a[i].X for i in range(A)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('74/74_2/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
