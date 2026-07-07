"""
Feasibility checker for the Arc Flow Model for 1D Bin Packing.
Based on: Carvalho (1999), Annals of Operations Research 86, 629-659.

Checks constraints:
  (1) Flow conservation (Eq 8)
  (2) Demand satisfaction (Eq 9)
  (3) Non-negativity (Eq 10)
  (4) Integrality (Eq 11)
  (5) Integer-domain auto-check on arc_flows / z
  (6) Non-negativity auto-check on arc_flows / z
  (7) Objective consistency: reported objective_value must equal the true
      number of bins used, i.e. len(bin_assignments). Defends against
      score-gaming solutions that pass constraints (1)-(6) but lie about
      the cost.
"""

import argparse
import json
from collections import defaultdict


def main():
    parser = argparse.ArgumentParser(
        description="Feasibility checker for Arc Flow Bin Packing (Carvalho 1999)"
    )
    parser.add_argument("--instance_path", type=str, required=True,
                        help="Path to the JSON instance file")
    parser.add_argument("--solution_path", type=str, required=True,
                        help="Path to the JSON solution file")
    parser.add_argument("--result_path", type=str, required=True,
                        help="Path to write the JSON feasibility result")
    args = parser.parse_args()

    with open(args.instance_path) as f:
        instance = json.load(f)
    with open(args.solution_path) as f:
        solution = json.load(f)

    result = check_feasibility(instance, solution)

    with open(args.result_path, "w") as f:
        json.dump(result, f, indent=2)

    print(f"Feasibility result written to {args.result_path}")
    print(f"Feasible: {result['feasible']}")
    if not result["feasible"]:
        print(f"Violated constraints: {result['violated_constraints']}")
        for v in result["violations"]:
            print(f"  - {v}")


def check_feasibility(instance, solution):
    W = instance["bin_capacity"]
    items = instance["items"]

    # Group items by size to get demands (sorted decreasing)
    size_counts = defaultdict(int)
    for s in items:
        size_counts[s] += 1
    sizes = sorted(size_counts.keys(), reverse=True)
    demands = [size_counts[s] for s in sizes]
    m = len(sizes)

    tol = 1e-5
    eps = 1e-5

    violations = []
    violated_constraints = set()
    violation_magnitudes = []

    # ---- Parse solution: original structure is bin_assignments (list of
    # dicts with 'items'); legacy 'bins' is also accepted. We reconstruct
    # arc flows internally for arc-flow conservation checks. ----
    bins_input = None
    if "bin_assignments" in solution:
        bins_input = solution["bin_assignments"]
    elif "bins" in solution:
        bins_input = solution["bins"]
    if bins_input is None:
        return {
            "feasible": False,
            "violated_constraints": [],
            "violations": ["Unknown solution format: 'bin_assignments' (or legacy 'bins') not found"],
            "violation_magnitudes": []
        }

    arc_flows = defaultdict(int)
    for bin_data in bins_input:
        bin_items = bin_data["items"]
        sorted_items = sorted(bin_items, reverse=True)
        pos = 0
        for item in sorted_items:
            arc_flows[(pos, pos + item)] += 1
            pos += item
        while pos < W:
            arc_flows[(pos, pos + 1)] += 1
            pos += 1
    arc_flows = dict(arc_flows)
    z = solution.get("num_bins", len(bins_input))

    # ---- Domain check on num_bins (z): integer >= 0 (paper Eq 11) ----
    violations_z = []
    if not isinstance(z, (int, float)):
        violations_z.append(
            f"Constraint 5 (integer domain): num_bins z={z!r} is not numeric")
    else:
        if z < -1e-9:
            violations_z.append(
                f"Constraint 6 (non-negativity): num_bins z = {z} < 0")
        if abs(z - round(z)) > 1e-6:
            violations_z.append(
                f"Constraint 5 (integer domain): num_bins z = {z} is not integer")
    violations.extend(violations_z)
    if violations_z:
        for msg in violations_z:
            cidx = 5 if "integer" in msg else 6
            violation_magnitudes.append({
                "constraint": cidx, "lhs": float(z), "rhs": 0.0 if cidx == 6 else round(z),
                "raw_excess": 1.0, "normalizer": 1.0, "ratio": 1.0,
            })

    # ---- Precompute inflow and outflow at each node ----
    inflow_at = defaultdict(float)
    outflow_at = defaultdict(float)
    for (i, j), v in arc_flows.items():
        outflow_at[i] += v
        inflow_at[j] += v

    # ================================================================
    # Constraint (1): Flow conservation (Eq 8)
    # ================================================================
    for node in range(W + 1):
        lhs_val = inflow_at[node] - outflow_at[node]
        if node == 0:
            rhs_val = float(-z)
        elif node == W:
            rhs_val = float(z)
        else:
            rhs_val = 0.0

        violation_amount = abs(lhs_val - rhs_val)
        if violation_amount > tol:
            violated_constraints.add(1)
            normalizer = max(abs(rhs_val), eps)
            violations.append(
                f"Flow conservation violated at node {node}: "
                f"net flow = {lhs_val}, expected {rhs_val}"
            )
            violation_magnitudes.append({
                "constraint": 1,
                "lhs": float(lhs_val),
                "rhs": float(rhs_val),
                "raw_excess": float(violation_amount),
                "normalizer": float(normalizer),
                "ratio": float(violation_amount / normalizer)
            })

    # ================================================================
    # Constraint (2): Demand constraints (Eq 9)
    # ================================================================
    for d_idx in range(m):
        w_d = sizes[d_idx]
        b_d = demands[d_idx]
        total_packed = sum(v for (i, j), v in arc_flows.items() if j - i == w_d)
        lhs_val = float(total_packed)
        rhs_val = float(b_d)
        violation_amount = max(rhs_val - lhs_val, 0.0)
        if violation_amount > tol:
            violated_constraints.add(2)
            normalizer = max(abs(rhs_val), eps)
            violations.append(
                f"Demand not met for item size {w_d}: "
                f"packed {int(lhs_val)}, required {b_d}"
            )
            violation_magnitudes.append({
                "constraint": 2,
                "lhs": lhs_val,
                "rhs": rhs_val,
                "raw_excess": float(violation_amount),
                "normalizer": float(normalizer),
                "ratio": float(violation_amount / normalizer)
            })

    # ================================================================
    # Constraint (3): Non-negativity (Eq 10)
    # ================================================================
    for (i, j), v in arc_flows.items():
        violation_amount = max(-v, 0.0)
        if violation_amount > tol:
            violated_constraints.add(3)
            normalizer = eps
            violations.append(
                f"Negative flow on arc ({i},{j}): x = {v}"
            )
            violation_magnitudes.append({
                "constraint": 3,
                "lhs": float(v),
                "rhs": 0.0,
                "raw_excess": float(violation_amount),
                "normalizer": float(normalizer),
                "ratio": float(violation_amount / normalizer)
            })

    # ================================================================
    # Constraint (4): Integrality (Eq 11)
    # ================================================================
    for (i, j), v in arc_flows.items():
        nearest_int = round(v)
        violation_amount = abs(v - nearest_int)
        if violation_amount > tol:
            violated_constraints.add(4)
            normalizer = max(abs(nearest_int), eps)
            violations.append(
                f"Non-integer flow on arc ({i},{j}): x = {v}"
            )
            violation_magnitudes.append({
                "constraint": 4,
                "lhs": float(v),
                "rhs": float(nearest_int),
                "raw_excess": float(violation_amount),
                "normalizer": float(normalizer),
                "ratio": float(violation_amount / normalizer)
            })

    # ---- Build output ----
    _domain_check_vars_binary = []
    _domain_check_vars_integer = [("arc_flows", arc_flows)]

    # =====================================================================
    # Non-negativity check for carvalho1999
    arc_flows_dict = solution.get("arc_flows", {})
    if isinstance(arc_flows_dict, dict):
        for arc, val in arc_flows_dict.items():
            try:
                v = float(val)
            except (TypeError, ValueError):
                continue
            if v < -tol:
                violated_constraints.add(6)
                violations.append(
                    f"Constraint 6 (non-negativity): arc_flows[{arc}] = {v} < 0"
                )
                violation_magnitudes.append({
                    "constraint": 6, "lhs": v, "rhs": 0.0,
                    "raw_excess": -v, "normalizer": max(abs(v), eps),
                    "ratio": -v / max(abs(v), eps),
                })

    # =====================================================================
    # Constraint 5: Integer domain
    for var_name, var_dict in _domain_check_vars_integer:
        if isinstance(var_dict, dict):
            for key, val in var_dict.items():
                try:
                    v = float(val)
                except (TypeError, ValueError):
                    continue
                frac = abs(v - round(v))
                if frac > tol:
                    violated_constraints.add(5)
                    violations.append(
                        f"Constraint 5 (integer domain): {var_name}[{key}] = {v} is not integer")
                    violation_magnitudes.append({
                        "constraint": 5,
                        "lhs": v,
                        "rhs": round(v),
                        "raw_excess": float(frac),
                        "normalizer": max(abs(round(v)), eps),
                        "ratio": float(frac / max(abs(round(v)), eps)),
                    })

    # ================================================================
    # Constraint (7): Objective consistency.
    # The objective z is exactly the number of bins used. Recompute it
    # from len(bin_assignments) and reject if reported objective_value
    # disagrees by 0.5 or more (objective is integer-valued).
    # ================================================================
    reported_obj = solution.get("objective_value")
    if reported_obj is not None:
        try:
            reported = float(reported_obj)
        except (TypeError, ValueError):
            reported = None
        if reported is not None:
            true_obj = float(len(bins_input))
            abs_diff = abs(reported - true_obj)
            obj_tol = 0.5  # integer-valued objective
            if abs_diff > obj_tol:
                violated_constraints.add(7)
                normalizer = max(abs(true_obj), eps)
                violations.append(
                    f"Constraint 7 (objective consistency): reported "
                    f"objective_value={reported} differs from recomputed "
                    f"num_bins=len(bin_assignments)={true_obj} "
                    f"(|diff|={abs_diff:.3g}, tol={obj_tol})"
                )
                violation_magnitudes.append({
                    "constraint": 7,
                    "lhs": float(reported),
                    "rhs": float(true_obj),
                    "raw_excess": float(abs_diff),
                    "normalizer": float(normalizer),
                    "ratio": float(abs_diff / normalizer),
                })

    feasible = len(violated_constraints) == 0

    return {
        "feasible": feasible,
        "violated_constraints": sorted(violated_constraints),
        "violations": violations,
        "violation_magnitudes": violation_magnitudes
    }


if __name__ == "__main__":
    main()
