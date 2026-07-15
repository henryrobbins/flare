"""
Generate data.json for the p-Median Problem (p23).

The source (garcia2011, FrontierOR dataset) ships instances with up to 100
nodes and cost matrices derived from two-dimensional coordinates, far too
large for a Lean formulation to be tractable (the CF model has O(n^2)
variables and the CR model has O(n^2) covering constraints). Instead this
writes a small, hand-verified instance in the same schema: 6 nodes forming
two clear clusters, with p = 2 medians.

Costs are the rounded Euclidean distances between the node coordinates below.
The optimum was verified by brute force over all C(6, 2) = 15 median subsets:
opening medians {1, 4} serves {0, 1, 2} from node 1 and {3, 4, 5} from node 4
for a total cost of 9.

Output keys match problem.json (and formulation `a`'s own parametrization,
per this dataset's convention): n, p, c.
"""

import json
import math
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent / "data.json"

# Two clusters: {0, 1, 2} near the origin and {3, 4, 5} near x = 11.
COORDS = [
    [0, 0],
    [2, 1],
    [1, 3],
    [10, 0],
    [12, 2],
    [11, 4],
]
P = 2


def cost_matrix(coords: list[list[int]]) -> list[list[int]]:
    n = len(coords)
    c = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i != j:
                dx = coords[i][0] - coords[j][0]
                dy = coords[i][1] - coords[j][1]
                c[i][j] = round(math.sqrt(dx * dx + dy * dy))
    return c


def generate_data() -> dict:
    return {
        "n": len(COORDS),
        "p": P,
        "c": cost_matrix(COORDS),
    }


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2) + "\n")
    print(f"Data written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
