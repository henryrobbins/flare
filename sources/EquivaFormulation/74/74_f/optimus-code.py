# Code automatically generated from OptiMUS

# Problem type: LP        
# Problem description
'''
A scientist is conducting M different experiments to produce
electricity. Each experiment i produces A[i] units of
electricity and requires specific amounts of N types of resources as
defined by I[j][i]. The laboratory has Y[j] units
of each resource available. The scientist aims to determine the number of each
experiment to conduct in order to maximize the total electricity produced.
'''
# Import necessary libraries
import json
from gurobipy import *
     
# Create a new model
model = Model()

# Load data 
with open("74/74_f/parameters.json", "r") as f:
    data = json.load(f)
    
# @Def: definition of a target
# @Shape: shape of a target            
        
# Parameters 
# @Parameter M @Def: Number of experiments @Shape: [] 
M = data['M']
# @Parameter N @Def: Number of resource types @Shape: [] 
N = data['N']
# @Parameter Y @Def: Amount of resource j available @Shape: ['N'] 
Y = data['Y']
# @Parameter I @Def: Amount of resource j required for experiment i @Shape: ['N', 'M'] 
I = data['I']
# @Parameter A @Def: Amount of electricity produced by experiment i @Shape: ['M'] 
A = data['A']

# Variables 
# @Variable j @Def: The number of times each experiment is conducted @Shape: ['M'] 
j = model.addVars(M, vtype=GRB.CONTINUOUS, name="j")


# @Variable zed @Def: New variable representing the objective function @Shape: []
zed = model.addVar(vtype=GRB.CONTINUOUS, name="zed")
# Constraints 
# @Constraint Constr_1 @Def: The total metal required for all experiments does not exceed the available metal.
model.addConstr(quicksum(I[0][i] * j[i] for i in range(M)) <= Y[0])
# @Constraint Constr_2 @Def: The total acid required for all experiments does not exceed the available acid.
model.addConstr(quicksum(I[1][i] * j[i] for i in range(M)) <= Y[1])


# Constraint defining zed in terms of original variables
model.addConstr(zed == quicksum(j[i] * A[i] for i in range(M)))
# Objective 
# @Objective Objective @Def: Maximize the total electricity produced by conducting the experiments.
model.setObjective(zed, GRB.MAXIMIZE)

# Solve 
model.optimize()
model.write("74/74_f/model.lp")

# Extract solution 
solution = {}
variables = {}
variables['zed'] = zed.x
objective = []
variables['j'] = {i: j[i].X for i in range(M)}
solution['variables'] = variables
solution['objective'] = model.objVal
with open('74/74_f/solution.json', 'w') as f:
    json.dump(solution, f, indent=4)
