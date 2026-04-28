"""
Generate synthetic PDPTW problem data for problem 10.

Places K truck depots and N job locations at random 2-D coordinates and
derives all travel times from Euclidean distances. This construction
automatically satisfies every assumption in formulation a:

  1. d[i][j] > 0 for all i != j  (distinct random coords, checked)
  2. Triangle inequality for d    (Euclidean metric)
  3. Triangle inequality for d0   (Euclidean metric)
  4. tau_min[i] >= 0
  5. tau_max[i] >= 0

d[i][i] is set to SERVICE_TIME, a strictly positive service duration.
The triangle inequality on d requires d[i][i] <= 2 * d[i][m] for all m;
the value is verified before writing.

Time windows are centred on each job's earliest reachable arrival time
from the nearest truck depot.
"""

import json
import math
import random
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
OUTPUT_PATH = SCRIPT_DIR / "data.json"

# ── problem size ──────────────────────────────────────────────────────────────
K = 40         # trucks
N = 65         # jobs
SEED = 42
GRID_SIZE = 100.0

# ── time-window parameters ────────────────────────────────────────────────────
# Each truck is available from time 0.
TRUCK_READY_TIME = 0.0
# Time-window half-width around the earliest feasible arrival.
WINDOW_HALF = 20.0
# d[i][i] = SERVICE_FRACTION * min_j(d[i][j] for j != i).
# Must be < 2 to satisfy d[i][i] <= 2*d[i][m] for all m; use 0.5 for margin.
SERVICE_FRACTION = 0.5


def euclidean(p1: tuple, p2: tuple) -> float:
    return math.sqrt((p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2)


def main() -> None:
    rng = random.Random(SEED)

    # Random depot and job locations
    depot_locs = [(rng.uniform(0, GRID_SIZE), rng.uniform(0, GRID_SIZE)) for _ in range(K)]
    job_locs = [(rng.uniform(0, GRID_SIZE), rng.uniform(0, GRID_SIZE)) for _ in range(N)]

    # ── travel-time matrices ──────────────────────────────────────────────────
    # d[i][j]: off-diagonal = Euclidean distance between job locations
    #          diagonal     = SERVICE_FRACTION * nearest-neighbour distance
    #          (ensures d[i][i] <= 2*d[i][m] for all m, satisfying triangle ineq.)
    d = [[0.0] * N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            if i != j:
                d[i][j] = euclidean(job_locs[i], job_locs[j])
    for i in range(N):
        nearest = min(d[i][j] for j in range(N) if j != i)
        d[i][i] = SERVICE_FRACTION * nearest

    # d0[k][i]: depot k → job i
    d0 = [[euclidean(depot_locs[k], job_locs[i]) for i in range(N)] for k in range(K)]

    # dH[k][i]: job i → depot k  (Euclidean is symmetric, so same as d0)
    dH = [[euclidean(job_locs[i], depot_locs[k]) for i in range(N)] for k in range(K)]

    # ── truck availability ────────────────────────────────────────────────────
    v = [TRUCK_READY_TIME] * K

    # ── time windows ──────────────────────────────────────────────────────────
    # Earliest arrival = min over k of (v[k] + d0[k][i])
    tau_min = []
    tau_max = []
    for i in range(N):
        earliest = min(v[k] + d0[k][i] for k in range(K))
        tau_min.append(round(earliest, 6))
        tau_max.append(round(earliest + 2 * WINDOW_HALF, 6))

    # ── verify all assumptions in formulation a ───────────────────────────────
    _verify(K, N, d, d0, tau_min, tau_max)

    data = {
        "K": K,
        "N": N,
        "d": d,
        "d0": d0,
        "dH": dH,
        "v": v,
        "tau_min": tau_min,
        "tau_max": tau_max,
    }

    OUTPUT_PATH.write_text(json.dumps(data, indent=2))
    print(f"Written {OUTPUT_PATH}  (K={K}, N={N})")


def _verify(K, N, d, d0, tau_min, tau_max) -> None:
    eps = 1e-9

    # 1. All off-diagonal travel times strictly positive
    for i in range(N):
        for j in range(N):
            if i != j:
                assert d[i][j] > 0, f"d[{i}][{j}] = {d[i][j]} is not > 0"

    # 1b. Diagonal (service times / rejection penalties) strictly positive
    for i in range(N):
        assert d[i][i] > 0, f"d[{i}][{i}] = {d[i][i]} is not > 0"

    # 2. Triangle inequality: d[i][j] <= d[i][m] + d[m][j]  (includes i==j cases)
    for i in range(N):
        for j in range(N):
            for m in range(N):
                assert d[i][j] <= d[i][m] + d[m][j] + eps, (
                    f"d triangle violated: d[{i}][{j}]={d[i][j]:.4f} > "
                    f"d[{i}][{m}]+d[{m}][{j}]={d[i][m]+d[m][j]:.4f}"
                )

    # 3. Triangle inequality: d0[k][i] <= d0[k][j] + d[j][i]
    for k in range(K):
        for i in range(N):
            for j in range(N):
                assert d0[k][i] <= d0[k][j] + d[j][i] + eps, (
                    f"d0 triangle violated: d0[{k}][{i}]={d0[k][i]:.4f} > "
                    f"d0[{k}][{j}]+d[{j}][{i}]={d0[k][j]+d[j][i]:.4f}"
                )

    # 4–5. Non-negative time windows
    for i in range(N):
        assert tau_min[i] >= 0, f"tau_min[{i}] = {tau_min[i]} < 0"
        assert tau_max[i] >= 0, f"tau_max[{i}] = {tau_max[i]} < 0"
        assert tau_max[i] >= tau_min[i], (
            f"tau_max[{i}]={tau_max[i]} < tau_min[{i}]={tau_min[i]}"
        )

    print("All assumptions verified.")


if __name__ == "__main__":
    main()
