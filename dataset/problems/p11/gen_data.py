"""
Generate data.json (SHUC) using a seeded random instance generator.

Generates a small reproducible SHUC instance with T=12 sub-hour periods,
n_G=5 thermal generators, and n_W=1 wind generator. All parameters are
drawn from distributions calibrated to match pglib-uc instance statistics:
convex piecewise production costs, two startup categories (warm/cold), ramp
limits, and minimum up/down times. Demand is set to roughly 65% of total
installed capacity so the instance is feasible but non-trivial.

--- pglib-uc fallback (preserved, not used by default) ---

The original implementation cloned pglib-uc and parsed instance
ca/2014-09-01_reserves_3.json. That logic is kept below
(clone_or_skip / parse_instance / main_pglib) and can be restored by
calling main_pglib() instead of main().
"""

import json
import math
import random
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
REPO_URL = "https://github.com/power-grid-lib/pglib-uc.git"
REPO_DIR = DATA_SOURCE_DIR / "pglib-uc"
INSTANCE_PATH = REPO_DIR / "ca" / "2014-09-01_reserves_3.json"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

# Random instance parameters
SEED = 42
T = 12  # sub-hour time periods
N_G = 5  # thermal generators
N_W = 1  # wind generators


# ---------------------------------------------------------------------------
# Random instance generator
# ---------------------------------------------------------------------------


def _linspace(lo: float, hi: float, n: int) -> list[float]:
    if n == 1:
        return [lo]
    return [lo + (hi - lo) * i / (n - 1) for i in range(n)]


def generate_instance(seed: int, T: int, n_G: int, n_W: int) -> dict:
    rng = random.Random(seed)

    # --- Thermal generators ---
    P_min, P_max = [], []
    n_L_list, P_list, C_list, C_fixed = [], [], [], []
    RU, RD, SU, SD = [], [], [], []
    U_list, D_list, MR = [], [], []
    n_S_list, ell_list, C_su_list = [], [], []

    for _ in range(n_G):
        pmin = round(rng.uniform(20, 100), 1)
        pmax = round(pmin + rng.uniform(80, 300), 1)
        P_min.append(pmin)
        P_max.append(pmax)

        # Piecewise production: 2 or 3 breakpoints
        n_l = rng.choice([2, 3])
        p_pts = [round(x, 1) for x in _linspace(pmin, pmax, n_l)]
        # Convex increasing marginal cost ($/MWh * capacity -> $/h)
        base_rate = rng.uniform(10, 40)  # $/MWh at P_min
        marg_inc = rng.uniform(0.05, 0.20)  # $/MWh per MW (convexity slope)
        c_pts = []
        for i, pp in enumerate(p_pts):
            rate = base_rate + marg_inc * (pp - pmin)
            c_pts.append(round(rate * pp, 2))
        n_L_list.append(n_l)
        P_list.append(p_pts)
        C_list.append(c_pts)
        C_fixed.append(c_pts[0])

        # Ramp limits: 30–70% of range per period
        ramp_frac = rng.uniform(0.30, 0.70)
        ru = round(ramp_frac * (pmax - pmin), 1)
        RU.append(ru)
        RD.append(ru)
        # Startup/shutdown ramp: 40–100% of P_max
        su_frac = rng.uniform(0.40, 1.00)
        SU.append(round(su_frac * pmax, 1))
        SD.append(round(su_frac * pmax, 1))

        # Minimum up/down times
        up = rng.randint(1, 3)
        dn = rng.randint(1, 3)
        U_list.append(up)
        D_list.append(dn)
        MR.append(0)

        # Startup categories: warm (lag=1) and cold (lag=up+1)
        cold_lag = max(up + 1, 2)
        warm_cost = round(rng.uniform(100, 500), 2)
        cold_cost = round(warm_cost * rng.uniform(1.5, 3.0), 2)
        n_S_list.append(2)
        ell_list.append([1, cold_lag])
        C_su_list.append([warm_cost, cold_cost])

    # --- Wind generators ---
    P_wind_min = [[0.0] * T for _ in range(n_W)]
    P_wind_max = [[round(rng.uniform(0, 50), 1) for _ in range(T)] for _ in range(n_W)]

    # --- Demand and reserve ---
    # Target ~65% of total installed thermal capacity
    total_cap = sum(P_max)
    base_load = 0.65 * total_cap
    # Sinusoidal daily variation ±15% around base load
    L = []
    wind_mean = sum(sum(P_wind_max[w]) / T for w in range(n_W))
    for t in range(T):
        factor = 1.0 + 0.15 * math.sin(2 * math.pi * t / T)
        noise = rng.uniform(-0.05, 0.05)
        # Subtract half the mean wind contribution so net demand stays feasible
        load = round(base_load * (factor + noise) - wind_mean * 0.5, 1)
        L.append(max(0.0, load))

    # Reserve = 10% of demand
    R = [round(0.10 * lt, 1) for lt in L]

    return {
        "T": T,
        "n_G": n_G,
        "n_W": n_W,
        "n_S": n_S_list,
        "ell": ell_list,
        "C_su": C_su_list,
        "n_L": n_L_list,
        "P": P_list,
        "C": C_list,
        "C_fixed": C_fixed,
        "L": L,
        "R": R,
        "P_min": P_min,
        "P_max": P_max,
        "P_wind_min": P_wind_min,
        "P_wind_max": P_wind_max,
        "RU": RU,
        "RD": RD,
        "SU": SU,
        "SD": SD,
        "U": U_list,
        "D": D_list,
        "MR": MR,
    }


# ---------------------------------------------------------------------------
# pglib-uc fallback (preserved; not called by default)
# ---------------------------------------------------------------------------


def clone_or_skip() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not REPO_DIR.exists():
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(REPO_DIR)],
            check=True,
        )


def parse_instance(fp: Path) -> dict:
    raw = json.loads(fp.read_text())

    T_raw = raw["time_periods"]
    L_raw = raw["demand"]
    R_raw = raw["reserves"]

    gens = list(raw["thermal_generators"].values())
    n_G_raw = len(gens)

    winds = list(raw.get("renewable_generators", {}).values())
    n_W_raw = len(winds)

    n_S, ell, C_su = [], [], []
    n_L, P, C = [], [], []
    C_fixed_raw = []
    P_min_raw, P_max_raw = [], []
    RU_raw, RD_raw, SU_raw, SD_raw = [], [], [], []
    U_raw, D_raw, MR_raw = [], [], []

    for g in gens:
        su = g["startup"]
        n_S.append(len(su))
        ell.append([s["lag"] for s in su])
        C_su.append([s["cost"] for s in su])

        pw = g["piecewise_production"]
        n_L.append(len(pw))
        P.append([pt["mw"] for pt in pw])
        C.append([pt["cost"] for pt in pw])
        C_fixed_raw.append(pw[0]["cost"])

        P_min_raw.append(g["power_output_minimum"])
        P_max_raw.append(g["power_output_maximum"])
        RU_raw.append(g["ramp_up_limit"])
        RD_raw.append(g["ramp_down_limit"])
        SU_raw.append(g["ramp_startup_limit"])
        SD_raw.append(g["ramp_shutdown_limit"])
        U_raw.append(g["time_up_minimum"])
        D_raw.append(g["time_down_minimum"])
        MR_raw.append(g["must_run"])

    P_wind_min_raw = [
        [w["power_output_minimum"][t] for t in range(T_raw)] for w in winds
    ]
    P_wind_max_raw = [
        [w["power_output_maximum"][t] for t in range(T_raw)] for w in winds
    ]

    return {
        "T": T_raw,
        "n_G": n_G_raw,
        "n_W": n_W_raw,
        "n_S": n_S,
        "ell": ell,
        "C_su": C_su,
        "n_L": n_L,
        "P": P,
        "C": C,
        "C_fixed": C_fixed_raw,
        "L": L_raw,
        "R": R_raw,
        "P_min": P_min_raw,
        "P_max": P_max_raw,
        "P_wind_min": P_wind_min_raw,
        "P_wind_max": P_wind_max_raw,
        "RU": RU_raw,
        "RD": RD_raw,
        "SU": SU_raw,
        "SD": SD_raw,
        "U": U_raw,
        "D": D_raw,
        "MR": MR_raw,
    }


def main_pglib() -> None:
    """Original pglib-uc-based data generation (preserved fallback)."""
    clone_or_skip()
    inst = parse_instance(INSTANCE_PATH)
    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    inst = generate_instance(SEED, T, N_G, N_W)
    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


if __name__ == "__main__":
    main()
