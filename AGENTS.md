# FLARE Agent Guide

This monorepo contains a dataset of MILP problems/formulations. Proofs that one formulation is a reformulation of another (for formulations of the same problem) are given in Lean 4. Additionally, there is a Python package and Python scripts for working with the dataset.

## Top-level layout

```
.
├── Common.lean              # MILPFormulation / MILPReformulation definitions
├── dataset/                 # the dataset (MILP problems, formulations, reformulations)
├── packages/
│   └── formulation_bench/   # publishable Python package `formulation_bench`
├── src/                     # experiment code (LLM client, prompts, verifiers)
├── experiments/             # experiment entry-point scripts
├── scripts/                 # standalone utility scripts
├── lakefile.toml
├── lean-toolchain
└── pyproject.toml
```

## `Common.lean`

Defines the two structures that the Lean files in `dataset/` build on:

- `MILPFormulation` — `Params`, `Vars`, `feasible`, `obj`.
- `MILPReformulation F G` — `paramMap`, `fwd`, `bwd`, `fwd_feas`, `bwd_feas`,
  `objMap`, `objMap_mono`, `fwd_obj`, `bwd_obj`.

Every formulation and reformulation file in `dataset/` imports this module
via `import Common`.

## `dataset/`

The dataset itself — MILP problems, their formulations, and reformulation
proofs. See `dataset/README.md` for more information.

## `packages/formulation_bench/`

Publishable Python package `formulation_bench` (src layout under
`packages/formulation_bench/src/formulation_bench/`) with modules for loading
and manipulating the dataset: `dataset.py`, `problem.py`, `formulation.py`,
`pair.py`, `models.py`. Tests are under `packages/formulation_bench/tests/`.
Owns its own `pyproject.toml` and is wired into the workspace root.

## `src/`

Experiment code (not published): `llm_client.py`, prompt templates under
`prompts/`, and reformulation-verifier implementations under `verify/`
(`equivamap/`, `execution/`, `flare/`, `llm/`) sharing a `verify/base.py`
interface. Installed editable as the package `src`.

## `experiments/`

Entry-point scripts (`baseline.py`, `ablation.py`)
that import from `src` and `formulation_bench`.

## `scripts/`

Standalone utility scripts that use `formulation_bench`:

- `scripts/dataset/validate_solve.py` — regenerate `solve.py` for every formulation, then gen_params + solve and verify objectives.

## Common Workflows

The repo provides a set of skills and agents for working with this dataset. This section outlines how these skills/agents should be utilized for different common workflows.

**Generate a Lean MILP formulation**

1. Identify the relevant source file(s) to read. E.g., the relevant source files for problem 1, formulation e (p1.e) are the problem files in the `dataset/problems/p1` directory and the formulation files in the `dataset/problems/p1/formulations/e` directory. If the user requests generating formulations for a problem, generate all of the problem's formulations.
2. The output file(s) will be `Formulation.lean` in each formulation's subdirectory. E.g., the formulation for p1.e goes in `dataset/problems/p1/formulations/e/Formulation.lean`.
3. Invoke the `milp-formulator` agent with the identified source/output. If generating multiple formulations, invoke multiple agents in parallel.

**Generate Lean MILP reformulation proof**

1. Identify the relevant source file(s) to read. At a minimum, you must read each MILP's `Formulation.lean` file. It may also be useful to read the problem and formulation files. E.g., the relevant source files for proving that p1.b is a reformulation of p1.a are the problem files in `dataset/problems/p1` and the formulation files `dataset/problems/p1/formulations/a|b`. The formulation subdirectory should contain `Formulation.lean` for both formulations. If it doesn't follow the steps above for generating it.
2. The output file for proving that formulation b is a reformulation of formulation a (for problem X) is `dataset/reformulations/pX/a_b.lean`.
3. Invoke the `milp-reformulation-autoformalizer` agent with the identified source/output. If generating multiple formulations, invoke multiple agents in parallel.

**Review existing Lean MILP formulations or reformulation proofs**

1. Identify the relevant file(s) to read. This includes relevant problem files, formulation files, MILP formulation `Formulation.lean` and reformulation proofs `dataset/reformulations/pX/a_b.lean`.
2. Invoke the `milp-reviewer` agent pointing to the relevant file locations. If generating multiple formulations, invoke multiple agents in parallel.
