"""
Generate data.json for the One-Dimensional Bin Packing problem (p22).

The source (carvalho1999, FrontierOR dataset) ships instances with a bin
capacity of 1000 and dozens of distinct item sizes, far too large for a Lean
formulation to be tractable (the arc-flow model alone has O(W) vertices and
O(W * m) arcs). Instead this writes a small, hand-verified instance in the
same schema (bin capacity and a list of item sizes) that is tight against the
volume lower bound ceil(sum(l) / W): six items of sizes 6, 6, 5, 5, 4, 4 pack
perfectly into 3 bins of capacity 10 ({6,4}, {6,4}, {5,5}).

Output keys match problem.json (and formulation `a`'s own parametrization,
per this dataset's convention): W, n, l.
"""

import json
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent / "data.json"

W = 10
l = [6, 6, 5, 5, 4, 4]


def generate_data() -> dict:
    return {
        "W": W,
        "n": len(l),
        "l": l,
    }


def main() -> None:
    data = generate_data()
    OUTPUT_PATH.write_text(json.dumps(data, indent=2) + "\n")
    print(f"Data written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
