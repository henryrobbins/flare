"""
Generate data.json (JSSP) using Taillard's benchmark generator.

The instance is generated via the algorithm from:
  Taillard, E. D.: "Benchmarks for basic scheduling problems",
  EJOR vol. 64, pp. 278-285, 1993.

The generator uses a Park-Miller LCG (same constants as the original C code)
to first draw uniform processing times in [1, 99], then randomly permutes the
machine assignment for each job using a Fisher-Yates shuffle driven by the
same LCG with a separate seed.

Seeds used below are the ta01 seeds (rand_time=840612802, rand_mach=398197754)
with NUM_JOBS=10 and NUM_MACH=10 to produce a small, reproducible instance.

--- JSPLIB fallback (preserved, not used by default) ---

The original implementation cloned JSPLIB and parsed Taillard instance files.
That logic is kept below (clone_or_update / parse_taillard_file / main_jsplib)
and can be restored by calling main_jsplib() instead of main().
"""

import json
import math
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_SOURCE_DIR = SCRIPT_DIR / "data_source"
REPO_URL = "git@github.com:tamy0612/JSPLIB.git"
REPO_DIR = DATA_SOURCE_DIR / "JSPLIB"
INSTANCES_DIR = REPO_DIR / "instances"
OUTPUT_PATH = SCRIPT_DIR / "data.json"

# Instance size and seeds
NUM_JOBS = 10
NUM_MACH = 10
RAND_TIME = 840612802  # ta01 rand_time seed
RAND_MACH = 398197754  # ta01 rand_mach seed


# ---------------------------------------------------------------------------
# Taillard generator
# ---------------------------------------------------------------------------


def _taillard_unif(seed: int, low: int, high: int) -> tuple[int, int]:
    """One step of the Park-Miller LCG used by Taillard; returns (new_seed, value)."""
    m = 2147483647
    a = 16807
    b = 127773
    c = 2836
    k = seed // b
    seed = a * (seed % b) - k * c
    if seed < 0:
        seed += m
    value = low + int(math.floor((seed / m) * (high - low + 1)))
    return seed, value


def taillard_generate(
    num_jobs: int, num_mach: int, rand_time: int, rand_mach: int
) -> dict:
    """Generate a JSSP instance with Taillard's method.

    Returns a dict with keys n, m, p (processing times), Om (machine order),
    matching the schema used by the rest of problem 8's pipeline.
    """
    time_seed = rand_time
    machine_seed = rand_mach

    # Draw processing times uniformly from [1, 99]
    d: list[list[int]] = [[0] * num_mach for _ in range(num_jobs)]
    for i in range(num_jobs):
        for j in range(num_mach):
            time_seed, d[i][j] = _taillard_unif(time_seed, 1, 99)

    # Initialise machine order as identity, then Fisher-Yates shuffle per job
    M: list[list[int]] = [[j for j in range(num_mach)] for _ in range(num_jobs)]
    for i in range(num_jobs):
        for j in range(num_mach):
            machine_seed, k = _taillard_unif(machine_seed, j, num_mach - 1)
            M[i][j], M[i][k] = M[i][k], M[i][j]

    return {"n": num_jobs, "m": num_mach, "p": d, "Om": M}


# ---------------------------------------------------------------------------
# JSPLIB fallback (preserved; not called by default)
# ---------------------------------------------------------------------------


def clone_or_update() -> None:
    DATA_SOURCE_DIR.mkdir(exist_ok=True)
    if not REPO_DIR.exists():
        subprocess.run(
            ["git", "clone", "--depth=1", REPO_URL, str(REPO_DIR)],
            check=True,
        )


def parse_taillard_file(fp: Path) -> dict:
    lines = fp.read_text().splitlines()
    n, m = map(int, lines[0].split())

    p: list[list[int]] = []
    Om: list[list[int]] = []

    for i in range(1, n + 1):
        tokens = list(map(int, lines[i].split()))
        machines = tokens[0::2]
        times = tokens[1::2]
        Om.append(machines)
        p.append(times)

    return {"n": n, "m": m, "p": p, "Om": Om}


def main_jsplib(instance_name: str = "ta01") -> None:
    """Original JSPLIB-based data generation (preserved fallback)."""
    clone_or_update()
    files = sorted(INSTANCES_DIR.glob(instance_name))
    if not files:
        raise FileNotFoundError(
            f"No files matching '{instance_name}' in {INSTANCES_DIR}"
        )
    inst = parse_taillard_file(files[0])
    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    inst = taillard_generate(NUM_JOBS, NUM_MACH, RAND_TIME, RAND_MACH)
    OUTPUT_PATH.write_text(json.dumps(inst, indent=2))


if __name__ == "__main__":
    main()
