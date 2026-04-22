"""
Clone pglib-uc and write data.json (SHUC).

Source: https://github.com/power-grid-lib/pglib-uc
Instance: ca/2014-09-01_reserves_3.json

Parameters written match problem.json. n_L is stored as a list of length n_G
(number of piecewise breakpoints per generator) because breakpoint counts vary
(1–3) across generators; P and C are correspondingly ragged lists of lists.
C_fixed[g] = piecewise_production[0]["cost"], i.e. the cost at minimum output
(the fixed on-cost per period in the SHUC formulation).
"""

import json
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
REPO_URL = "https://github.com/power-grid-lib/pglib-uc.git"
REPO_DIR = DATA_SOURCE_DIR / "pglib-uc"
INSTANCE_PATH = REPO_DIR / "ca" / "2014-09-01_reserves_3.json"
OUTPUT_PATH = SCRIPT_DIR / "data.json"


def clone_or_skip() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not REPO_DIR.exists():
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(REPO_DIR)],
            check=True,
        )


def parse_instance(fp: Path) -> dict:
    raw = json.loads(fp.read_text())

    T = raw["time_periods"]
    L = raw["demand"]       # length T
    R = raw["reserves"]     # length T

    gens = list(raw["thermal_generators"].values())
    n_G = len(gens)

    winds = list(raw.get("renewable_generators", {}).values())
    n_W = len(winds)

    n_S, ell, C_su = [], [], []
    n_L, P, C = [], [], []
    C_fixed = []
    P_min, P_max = [], []
    RU, RD, SU, SD = [], [], [], []
    U, D, MR = [], [], []

    for g in gens:
        # Startup categories
        su = g["startup"]
        n_S.append(len(su))
        ell.append([s["lag"] for s in su])
        C_su.append([s["cost"] for s in su])

        # Piecewise production
        pw = g["piecewise_production"]
        n_L.append(len(pw))
        P.append([pt["mw"] for pt in pw])
        C.append([pt["cost"] for pt in pw])
        C_fixed.append(pw[0]["cost"])  # fixed on-cost = cost at P_min

        P_min.append(g["power_output_minimum"])
        P_max.append(g["power_output_maximum"])
        RU.append(g["ramp_up_limit"])
        RD.append(g["ramp_down_limit"])
        SU.append(g["ramp_startup_limit"])
        SD.append(g["ramp_shutdown_limit"])
        U.append(g["time_up_minimum"])
        D.append(g["time_down_minimum"])
        MR.append(g["must_run"])

    # Renewable generators (empty in this instance)
    P_wind_min = [[w["power_output_minimum"][t] for t in range(T)] for w in winds]
    P_wind_max = [[w["power_output_maximum"][t] for t in range(T)] for w in winds]

    return {
        "T": T,
        "n_G": n_G,
        "n_W": n_W,
        "n_S": n_S,
        "ell": ell,
        "C_su": C_su,
        "n_L": n_L,
        "P": P,
        "C": C,
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
        "U": U,
        "D": D,
        "MR": MR,
    }


def main() -> None:
    clone_or_skip()
    inst = parse_instance(INSTANCE_PATH)
    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


if __name__ == "__main__":
    main()
