import json
import gurobipy as gp
from gurobipy import GRB
import argparse


def main(params_path: str, solution_path: str) -> None:

    # Create a new model
    model = gp.Model()

    # Load data
    with open(params_path, "r") as f:
        data = json.load(f)

    # @Def: definition of a target
    # @Shape: shape of a target

    # Parameters
    # @Parameter n @Def: Number of jobs @Shape: []
    n = data['n']
    # @Parameter m @Def: Number of machines @Shape: []
    m = data['m']
    # @Parameter p @Def: Processing time of the k-th operation of job j @Shape: [n, m]
    p = data['p']
    # @Parameter Om @Def: Machine index assigned to the k-th operation of job j @Shape: [n, m]
    Om = data['Om']

    # Preprocessing: big-M (sum of all processing times)
    M_big = sum(p[j][k] for j in range(n) for k in range(m))

    # Preprocessing: conflict pairs -- ((j1,k1),(j2,k2)) sharing the same machine
    pairs = []
    for machine in range(m):
        ops = [(j, k) for j in range(n) for k in range(m) if Om[j][k] == machine]
        for i in range(len(ops)):
            for j2, k2 in ops[i + 1:]:
                pairs.append((ops[i], (j2, k2)))

    # Variables
    # @Variable S @Def: Start time of the k-th operation of job j @Shape: [n, m]
    S = model.addVars(n, m, lb=0.0, vtype=GRB.CONTINUOUS, name="S")
    # @Variable y @Def: 1 if operation (j1,k1) is scheduled before (j2,k2) on their shared machine @Shape: [|P|]
    y = model.addVars([(j1, k1, j2, k2) for (j1, k1), (j2, k2) in pairs], vtype=GRB.BINARY, name="y")
    # @Variable C_max @Def: Makespan (completion time of the last operation) @Shape: []
    C_max = model.addVar(lb=0.0, vtype=GRB.CONTINUOUS, name="C_max")

    # Constraints
    # @Constraint Constr_1 @Def: Technological ordering within each job.
    model.addConstrs(S[j, k + 1] >= S[j, k] + p[j][k] for j in range(n) for k in range(m - 1))
    # @Constraint Constr_2 @Def: Machine non-overlap (forward): if y=1, op (j1,k1) precedes (j2,k2).
    for (j1, k1), (j2, k2) in pairs:
        model.addConstr(S[j1, k1] + p[j1][k1] <= S[j2, k2] + M_big * (1 - y[j1, k1, j2, k2]))
    # @Constraint Constr_3 @Def: Machine non-overlap (reverse): if y=0, op (j2,k2) precedes (j1,k1).
    for (j1, k1), (j2, k2) in pairs:
        model.addConstr(S[j2, k2] + p[j2][k2] <= S[j1, k1] + M_big * y[j1, k1, j2, k2])
    # @Constraint Constr_4 @Def: Makespan is at least the completion time of each job's last operation.
    model.addConstrs(C_max >= S[j, m - 1] + p[j][m - 1] for j in range(n))
    # @Constraint Constr_5 @Def: Machine Critical-Path Bound (EC2, Version 2): CP_m = load_m + min_head + min_tail; makespan >= CP_m for each machine.
    for machine in range(m):
        ops_m = [(j, k) for j in range(n) for k in range(m) if Om[j][k] == machine]
        load_m = sum(p[j][k] for j, k in ops_m)
        min_head = min(sum(p[j][t] for t in range(k)) for j, k in ops_m)
        min_tail = min(sum(p[j][t] for t in range(k + 1, m)) for j, k in ops_m)
        model.addConstr(C_max >= load_m + min_head + min_tail)

    # Objective
    # @Objective Objective @Def: Minimize the makespan.
    model.setObjective(C_max, GRB.MINIMIZE)

    # Solve
    model.optimize()

    # Extract solution
    solution = {}
    variables = {}
    variables['S'] = [[S[j, k].x for k in range(m)] for j in range(n)]
    variables['y'] = {str([j1, k1, j2, k2]): y[j1, k1, j2, k2].x for (j1, k1), (j2, k2) in pairs}
    variables['C_max'] = C_max.x
    solution['variables'] = variables
    solution['objective'] = model.objVal
    with open(solution_path, 'w') as f:
        json.dump(solution, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("params", help="Path to parameters.json")
    parser.add_argument("solution", help="Path to write solution.json")
    args = parser.parse_args()
    main(args.params, args.solution)
