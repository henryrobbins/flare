import argparse
import json


def maximal_cliques(n: int, edges: list[list[int]]) -> list[list[int]]:
    """Enumerate all maximal cliques of a graph via Bron-Kerbosch."""
    adj: list[set[int]] = [set() for _ in range(n)]
    for i, j in edges:
        adj[i].add(j)
        adj[j].add(i)

    cliques: list[list[int]] = []

    def expand(r: set[int], p: set[int], x: set[int]) -> None:
        if not p and not x:
            cliques.append(sorted(r))
            return
        for v in list(p):
            expand(r | {v}, p & adj[v], x & adj[v])
            p.discard(v)
            x.add(v)

    expand(set(), set(range(n)), set())
    return cliques


def main(data_path: str, output_path: str) -> None:
    with open(data_path) as f:
        data = json.load(f)

    n = data["n"]
    edges = data["E"]

    cliques = maximal_cliques(n, edges)

    params = {
        "n": n,
        "P": data["P"],
        "clusterSize": data["clusterSize"],
        "clusters": data["clusters"],
        "q": len(cliques),
        "cliqueSize": [len(c) for c in cliques],
        "K": cliques,
    }

    with open(output_path, "w") as f:
        json.dump(params, f, indent=4)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("data", help="Path to data.json")
    parser.add_argument("output", help="Path to write parameters.json")
    args = parser.parse_args()
    main(args.data, args.output)
