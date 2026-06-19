"""Solve p7 (rectangular tiling with one hole per row/column) over a range of
N and plot the resulting tilings.

By default the base MILP is solved with Gurobi. Pass --cuts to add the V1
EC1/EC2 horizontal-break cuts, or --construct to use the constructive
algorithm instead of solving."""

import argparse
import math
import time

import gurobipy as gp
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
from gurobipy import GRB
from matplotlib.axes import Axes


def place_holes(N: int) -> list[tuple[int, int]]:
    """Place N holes (one per row/column) by the skip-n diagonal walk.

    - Skip n = floor(sqrt(N)): the unique integer with n^2 <= N < (n+1)^2.
    - First hole goes in the n-th row (1-indexed), i.e. row index n - 1.
    - From each hole, move right 1 column and down n rows. If that walks past
      the bottom of the grid, the next block starts one row above the current
      block (i.e. the topmost occupied row minus 1).
    """
    n = max(1, math.isqrt(N))
    holes: list[tuple[int, int]] = []
    row = n - 1
    block_start = row
    for c in range(N):
        holes.append((row, c))
        if row + n < N:
            row = row + n
        else:
            block_start -= 1
            row = block_start
    return holes


def place_tiles(
    N: int, holes: list[tuple[int, int]]
) -> list[tuple[int, int, int, int]]:
    """Greedily tile the non-hole cells.

    Scan rows top-to-bottom, columns left-to-right. At the first uncovered
    non-hole cell:
      1. Extend right until blocked by a hole, an existing tile, or the wall.
      2. If extension stopped at a hole, finalize the 1-row tile.
      3. Otherwise extend down row-by-row while the full [a..b] band below
         is clear, stopping as soon as the cell to the right of the new
         bottom-right corner is a hole (so the next row would violate EC2).
    """
    hole_set = set(holes)
    occupied = set(hole_set)
    tiles: list[tuple[int, int, int, int]] = []
    for i in range(N):
        for j in range(N):
            if (i, j) in occupied:
                continue
            a, b = j, j
            stopped_by_hole = False
            while b + 1 < N and (i, b + 1) not in occupied:
                b += 1
            if b + 1 < N and (i, b + 1) in hole_set:
                stopped_by_hole = True
            for col in range(a, b + 1):
                occupied.add((i, col))
            r0, r1 = i, i
            if not stopped_by_hole:
                while r1 + 1 < N and all(
                    (r1 + 1, col) not in occupied for col in range(a, b + 1)
                ):
                    r1 += 1
                    for col in range(a, b + 1):
                        occupied.add((r1, col))
                    if b + 1 < N and (r1, b + 1) in hole_set:
                        break
            tiles.append((r0, r1, a, b))
    return tiles


def construct(
    N: int,
) -> tuple[float, float, list[tuple[int, int, int, int]], list[tuple[int, int]]]:
    """Constructive p7 tiling: place holes diagonally, then greedy-fill."""
    t0 = time.perf_counter()
    holes = place_holes(N)
    tiles = place_tiles(N, holes)
    runtime = time.perf_counter() - t0
    return float(len(tiles)), runtime, tiles, holes


def solve(
    N: int, cuts: bool
) -> tuple[float, float, list[tuple[int, int, int, int]], list[tuple[int, int]]]:
    R = range(N)
    C = range(N)
    intervals = [(a, b) for a in C for b in range(a, N)]

    m = gp.Model("p7")
    m.Params.OutputFlag = 0

    h = m.addVars(N, N, vtype=GRB.BINARY, name="h")
    x = m.addVars(
        [(i, a, b) for i in R for (a, b) in intervals], vtype=GRB.BINARY, name="x"
    )
    s = m.addVars(
        [(i, a, b) for i in R for (a, b) in intervals], vtype=GRB.BINARY, name="s"
    )
    t = m.addVars(
        [(i, a, b) for i in R for (a, b) in intervals], vtype=GRB.BINARY, name="t"
    )

    m.addConstrs(gp.quicksum(h[i, j] for j in C) == 1 for i in R)
    m.addConstrs(gp.quicksum(h[i, j] for i in R) == 1 for j in C)
    m.addConstrs(
        gp.quicksum(x[i, a, b] for (a, b) in intervals if a <= j <= b) + h[i, j] == 1
        for i in R
        for j in C
    )
    m.addConstrs(x[0, a, b] - s[0, a, b] == 0 for (a, b) in intervals)
    m.addConstrs(
        x[i, a, b] - x[i - 1, a, b] - s[i, a, b] + t[i - 1, a, b] == 0
        for i in range(1, N)
        for (a, b) in intervals
    )
    m.addConstrs(x[N - 1, a, b] - t[N - 1, a, b] == 0 for (a, b) in intervals)

    if cuts:
        m.addConstrs(
            h[i, j] <= gp.quicksum(t[i, a, b] for (a, b) in intervals if b == j - 1)
            for i in R
            for j in range(1, N)
        )
        m.addConstrs(
            h[i, j] <= gp.quicksum(s[i, a, b] for (a, b) in intervals if a == j + 1)
            for i in R
            for j in range(N - 1)
        )

    m.setObjective(
        gp.quicksum(s[i, a, b] for i in R for (a, b) in intervals), GRB.MINIMIZE
    )
    m.optimize()

    tiles: list[tuple[int, int, int, int]] = []
    for a, b in intervals:
        for i in R:
            if s[i, a, b].X > 0.5:
                j = i
                while t[j, a, b].X < 0.5:
                    j += 1
                tiles.append((i, j, a, b))

    holes = [(i, j) for i in R for j in C if h[i, j].X > 0.5]
    return m.ObjVal, m.Runtime, tiles, holes


def draw(
    ax: Axes,
    N: int,
    tiles: list[tuple[int, int, int, int]],
    holes: list[tuple[int, int]],
    title: str,
) -> None:
    cmap = plt.get_cmap("tab20")
    for k, (r0, r1, a, b) in enumerate(tiles):
        ax.add_patch(
            mpatches.Rectangle(
                (a, N - 1 - r1),
                b - a + 1,
                r1 - r0 + 1,
                facecolor=cmap(k % 20),
                edgecolor="black",
                linewidth=1.0,
            )
        )
    for i, j in holes:
        ax.add_patch(
            mpatches.Rectangle(
                (j, N - 1 - i),
                1,
                1,
                facecolor="white",
                edgecolor="black",
                hatch="///",
                linewidth=1.0,
            )
        )
    ax.set_xlim(0, N)
    ax.set_ylim(0, N)
    ax.set_aspect("equal")
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_title(title, fontsize=9)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--n-min", type=int, default=3)
    parser.add_argument("--n-max", type=int, default=10)
    parser.add_argument("--out", default="p7_tilings.png")
    parser.add_argument(
        "--construct",
        action="store_true",
        help="Use the constructive algorithm instead of solving with Gurobi.",
    )
    parser.add_argument(
        "--cuts",
        action="store_true",
        help="Add the V1 EC1/EC2 horizontal-break cuts when solving with Gurobi.",
    )
    args = parser.parse_args()

    Ns = list(range(args.n_min, args.n_max + 1))
    results: dict[
        int,
        tuple[float, float, list[tuple[int, int, int, int]], list[tuple[int, int]]],
    ] = {}
    if args.construct:
        label = "construct"
    else:
        label = "EC1+EC2" if args.cuts else "base"
    for N in Ns:
        results[N] = construct(N) if args.construct else solve(N, cuts=args.cuts)
        obj, rt, _, _ = results[N]
        print(f"  N={N:2d} {label}  obj={int(obj)}  runtime={rt:.4f}s")

    ncols = 4
    nrows = (len(Ns) + ncols - 1) // ncols
    fig, axes = plt.subplots(
        nrows, ncols, figsize=(3.0 * ncols, 3.0 * nrows), squeeze=False
    )
    axes_flat = [ax for row in axes for ax in row]

    for ax, N in zip(axes_flat, Ns):
        obj, runtime, tiles, holes = results[N]
        draw(ax, N, tiles, holes, f"N={N}  tiles={int(obj)}  {runtime:.2f}s")

    for ax in axes_flat[len(Ns) :]:
        ax.axis("off")

    if args.construct:
        title = "p7: constructive tilings"
    elif args.cuts:
        title = "p7: optimal tilings with EC1+EC2 cuts"
    else:
        title = "p7: optimal tilings"
    fig.suptitle(title, y=1.0)
    fig.tight_layout()
    fig.savefig(args.out, dpi=150, bbox_inches="tight")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
