#!/usr/bin/env python3
"""Generate HuggingFace-ready JSONL files from the dataset.

Produces two files in the output directory:
  formulations.jsonl  -- one record per formulation
  pairs.jsonl         -- one record per pair (from pairs.json)
"""

import argparse
import json
from pathlib import Path

from formulation_bench import Dataset


def _read_text(path: Path) -> str | None:
    return path.read_text() if path.exists() else None


def build_formulation_record(pid: int, fid: str, problem, formulation) -> dict:
    lean_code = _read_text(formulation.path / "Formulation.lean")
    gen_params_code = _read_text(formulation.path / "gen_params.py")
    solve_code = _read_text(formulation.path / "solve.py")
    return {
        "problem_id": pid,
        "formulation_id": fid,
        "description": problem.description,
        "source": problem.metadata.get("source", {}),
        "valid": formulation.valid,
        "formulation": {
            "parameters": {
                k: {"description": v.description, "shape": v.shape}
                for k, v in formulation.parameters.items()
            },
            "variables": {
                k: {
                    "description": v.description,
                    "type": v.type,
                    "shape": v.shape,
                    **({"indices": v.indices} if v.indices else {}),
                }
                for k, v in formulation.variables.items()
            },
            "assumptions": [
                {
                    "description": a.description,
                    "formulation": a.formulation,
                    "explicit": a.explicit,
                }
                for a in formulation.assumptions
            ],
            "constraints": [
                {
                    "description": c.description,
                    "formulation": c.formulation,
                    "explicit": c.explicit,
                }
                for c in formulation.constraints
            ],
            "objective": {
                "description": formulation.objective.description,
                "formulation": formulation.objective.formulation,
            },
        },
        "lean_formulation": lean_code,
        "gen_params_code": gen_params_code,
        "solve_code": solve_code,
        "metadata": formulation.metadata,
    }


def build_pair_record(pair: dict, dataset_root: Path) -> dict:
    a, b = pair["a"], pair["b"]
    reformulation = pair["reformulation"]

    lean_proof = None
    if reformulation:
        fa, fb = a["formulation"], b["formulation"]
        # canonical ordering: alphabetically smaller first
        if fa > fb:
            fa, fb = fb, fa
        proof_path = (
            dataset_root / "reformulations" / f"p{a['problem']}" / f"{fa}_{fb}.lean"
        )
        lean_proof = _read_text(proof_path)

    return {
        "problem_id": a["problem"],
        "formulation_a": a["formulation"],
        "formulation_b": b["formulation"],
        "reformulation": reformulation,
        "lean_proof": lean_proof,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "dataset",
        nargs="?",
        default="dataset",
        help="path to the dataset root (default: ./dataset)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="dataset/data",
        help="output directory for JSONL files (default: ./dataset/data)",
    )
    args = parser.parse_args()

    dataset_root = Path(args.dataset)
    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    dataset = Dataset(str(dataset_root))

    # formulations.jsonl
    formulations_path = out_dir / "formulations.jsonl"
    count = 0
    with formulations_path.open("w") as f:
        for pid, problem in sorted(dataset.problems.items()):
            for fid, formulation in sorted(problem.formulations.items()):
                record = build_formulation_record(pid, fid, problem, formulation)
                f.write(json.dumps(record) + "\n")
                count += 1
    print(f"wrote {count} formulation records -> {formulations_path}")

    # pairs.jsonl
    pairs_file = dataset_root / "pairs.json"
    pairs = json.loads(pairs_file.read_text())
    pairs_path = out_dir / "pairs.jsonl"
    with pairs_path.open("w") as f:
        for pair in pairs:
            record = build_pair_record(pair, dataset_root)
            f.write(json.dumps(record) + "\n")
    print(f"wrote {len(pairs)} pair records     -> {pairs_path}")


if __name__ == "__main__":
    main()
