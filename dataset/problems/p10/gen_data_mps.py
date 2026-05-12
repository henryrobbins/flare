"""
Download a PDPTW instance from MIPLIB 2010 and write data.json (problem 10).

Source: https://miplib2010.zib.de/contrib/submission2010/f_jordan_srour/
Reads the MPS with Gurobi and recovers (K, N, d0, d, dH, v, tau_min, tau_max)
from the instance coefficients, following the formulation in Srour et al. (2010).

Formulation node ordering (0-indexed): trucks 0..K-1, jobs K..K+N-1.
Binary var x_p encodes arc (p // (K+N), p % (K+N)).
Continuous var x_{(K+N)^2 + i} encodes δ_i (arrival time at job i).

Currently writes a single instance (R0_1). To switch to another or all instances,
change INSTANCE_FILTER to None and set MULTI_INSTANCE = True.
"""

import gzip
import json
import math
import shutil
import urllib.request
from pathlib import Path

import gurobipy as gp

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
BASE_URL = "https://miplib2010.zib.de/contrib/submission2010/f_jordan_srour/"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

INSTANCES = [
    "R0_1",
    "R0_2",
    "R0_3",
    "R0_4",
    "R0_5",
    "R0_6",
    "R0_7",
    "R0_8",
    "R0_9",
    "R0_10",
    "R0_11",
    "R0_12",
    "R0_13",
    "R0_14",
    "R0_15",
    "R0_16",
    "R0_17",
    "R0_18",
    "R0_19",
    "R0_20",
    "R0_21",
    "R0_22",
    "R0_23",
    "R0_24",
    "R0_25",
    "R0_26",
    "R0_27",
    "R0_28",
    "R0_29",
    "R0_30",
    "R0_31",
    "R0_32",
    "R0_33",
    "R25_1",
    "R25_2",
    "R25_3",
    "R25_4",
    "R25_5",
    "R25_6",
    "R25_7",
    "R25_8",
    "R25_9",
    "R25_10",
    "R25_11",
    "R25_12",
    "R25_13",
    "R25_14",
    "R25_15",
    "R25_16",
    "R25_17",
    "R25_18",
    "R25_19",
    "R25_20",
    "R25_21",
    "R25_22",
    "R25_23",
    "R25_24",
    "R25_25",
    "R25_26",
    "R25_27",
    "R25_28",
    "R25_29",
    "R25_30",
    "R25_31",
    "R25_32",
    "R25_33",
    "R50_1",
    "R50_2",
    "R50_3",
    "R50_4",
    "R50_5",
    "R50_6",
    "R50_7",
    "R50_8",
    "R50_9",
    "R50_10",
    "R50_11",
    "R50_12",
    "R50_13",
    "R50_14",
    "R50_15",
    "R50_16",
    "R50_17",
    "R50_18",
    "R50_19",
    "R50_20",
    "R50_21",
    "R50_22",
    "R50_23",
    "R50_24",
    "R50_25",
    "R50_26",
    "R50_27",
    "R50_28",
    "R50_29",
    "R50_30",
    "R50_31",
    "R50_32",
    "R50_33",
    "R75_1",
    "R75_2",
    "R75_3",
    "R75_4",
    "R75_5",
    "R75_6",
    "R75_7",
    "R75_8",
    "R75_9",
    "R75_10",
    "R75_11",
    "R75_12",
    "R75_13",
    "R75_14",
    "R75_15",
    "R75_16",
    "R75_17",
    "R75_18",
    "R75_19",
    "R75_20",
    "R75_21",
    "R75_22",
    "R75_23",
    "R75_24",
    "R75_25",
    "R75_26",
    "R75_27",
    "R75_28",
    "R75_29",
    "R75_30",
    "R75_31",
    "R75_32",
    "R75_33",
    "R100_1",
    "R100_2",
    "R100_3",
    "R100_4",
    "R100_5",
    "R100_6",
    "R100_7",
    "R100_8",
    "R100_9",
    "R100_10",
    "R100_11",
    "R100_12",
    "R100_13",
    "R100_14",
    "R100_15",
    "R100_16",
    "R100_17",
    "R100_18",
    "R100_19",
    "R100_20",
    "R100_21",
    "R100_22",
    "R100_23",
    "R100_24",
    "R100_25",
    "R100_26",
    "R100_27",
    "R100_28",
    "R100_29",
    "R100_30",
    "R100_31",
    "R100_32",
    "R100_33",
]

# Set to None to pick randomly (seeded); set MULTI_INSTANCE = True to write a list.
INSTANCE_FILTER = "R0_1"
MULTI_INSTANCE = False
RANDOM_SEED = 42


def download_instance(name: str) -> Path:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    mps_path = DATA_SOURCE_DIR / f"{name}.mps"
    if mps_path.exists():
        return mps_path
    gz_path = DATA_SOURCE_DIR / f"{name}.mps.gz"
    if not gz_path.exists():
        url = BASE_URL + f"{name}.mps.gz"
        urllib.request.urlretrieve(url, gz_path)
    with gzip.open(gz_path, "rb") as f_in, mps_path.open("wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
    return mps_path


def parse_instance(mps_path: Path) -> dict:
    env = gp.Env()
    env.setParam("OutputFlag", 0)
    m = gp.read(str(mps_path), env)

    bin_vars = sorted(
        [v for v in m.getVars() if v.vtype == gp.GRB.BINARY],
        key=lambda v: int(v.varName[1:]),
    )
    cont_vars = sorted(
        [v for v in m.getVars() if v.vtype == gp.GRB.CONTINUOUS],
        key=lambda v: int(v.varName[1:]),
    )

    n_binary = len(bin_vars)
    N = len(cont_vars)
    n_nodes = int(math.isqrt(n_binary))
    assert n_nodes * n_nodes == n_binary
    K = n_nodes - N

    # Continuous var index offset (first continuous var's numeric index)
    cont_offset = int(cont_vars[0].varName[1:])

    def arc(v):
        idx = int(v.varName[1:])
        return idx // n_nodes, idx % n_nodes

    def job_idx(v):
        return int(v.varName[1:]) - cont_offset

    # Extract d, d0, dH from objective coefficients
    d = [[0.0] * N for _ in range(N)]
    d0 = [[0.0] * N for _ in range(K)]
    dH = [[0.0] * N for _ in range(K)]

    for v in bin_vars:
        obj = v.obj
        if obj == 0.0:
            continue
        u, w = arc(v)
        if u < K and w >= K:
            d0[u][w - K] = obj
        elif u >= K and w >= K:
            d[u - K][w - K] = obj
        elif u >= K and w < K:
            dH[w][u - K] = obj

    # Extract tau_min, tau_max, v from constraint structure
    tau_min = [None] * N
    tau_max = [None] * N
    v_trucks = [None] * K

    for constr in m.getConstrs():
        row = m.getRow(constr)
        sense = constr.sense
        rhs = constr.rhs

        cont_terms = []
        bin_terms = []
        for t in range(row.size()):
            var = row.getVar(t)
            coeff = row.getCoeff(t)
            if var.vtype == gp.GRB.BINARY:
                bin_terms.append((arc(var), coeff))
            else:
                cont_terms.append((job_idx(var), coeff))

        n_cont = len(cont_terms)
        n_bin = len(bin_terms)

        if sense == "<" and n_cont == 1 and n_bin == 0:
            # δ_i ≤ τ_max_i
            i, coeff = cont_terms[0]
            tau_max[i] = rhs / coeff

        elif sense == ">" and n_cont == 1 and n_bin == 0:
            # δ_i ≥ τ_min_i
            i, coeff = cont_terms[0]
            tau_min[i] = rhs / coeff

        elif sense == ">" and n_cont == 1 and n_bin > 0:
            # Constraint 3: δ_i ≥ Σ_k (d0[k][i] + v[k]) * x[k, K+i]
            # coeff of δ_i is +1; coeff of x[k,K+i] is -(d0[k][i] + v[k])
            i, d_coeff = cont_terms[0]
            if d_coeff < 0:
                continue  # unexpected sign; skip
            for (u, w), coeff in bin_terms:
                if u < K and w == K + i and v_trucks[u] is None:
                    v_trucks[u] = (-coeff) - d0[u][i]

    # Fill any unresolved values with defaults
    tau_min = [t if t is not None else 0.0 for t in tau_min]
    tau_max = [t if t is not None else float("inf") for t in tau_max]
    v_trucks = [t if t is not None else 0.0 for t in v_trucks]

    return {
        "K": K,
        "N": N,
        "d": d,
        "d0": d0,
        "dH": dH,
        "v": v_trucks,
        "tau_min": tau_min,
        "tau_max": tau_max,
    }


def main() -> None:
    if INSTANCE_FILTER:
        names = [INSTANCE_FILTER]
    else:
        import random

        rng = random.Random(RANDOM_SEED)
        names = (
            rng.sample(INSTANCES, len(INSTANCES))
            if MULTI_INSTANCE
            else [rng.choice(INSTANCES)]
        )

    instances = []
    for name in names:
        mps_path = download_instance(name)
        inst = parse_instance(mps_path)
        instances.append(inst)

    if MULTI_INSTANCE:
        OUTPUT_PATH.write_text(json.dumps(instances, indent=2))
    else:
        OUTPUT_PATH.write_text(json.dumps(instances[0], indent=2))


if __name__ == "__main__":
    main()
