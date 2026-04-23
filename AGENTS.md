# EquivaProof Agent Guide

This monorepo contains a dataset of MILP problems/formulations. Proofs of equivalence for equivalent formulations of the same problem are given in Lean 4. Additionally, there is a Python package and Python scripts for working with the dataset.

## Top-level layout

```
.
├── Common.lean       # MILPFormulation / MILPEquiv definitions
├── dataset/          # the dataset (MILP problems, formulations, equivalences)
├── python/           # Python package `milp_eq_tools`
├── scripts/          # standalone scripts
├── lakefile.toml
├── lean-toolchain
└── pyproject.toml
```

## `Common.lean`

Defines the two structures that the Lean files in `dataset/` build on:

- `MILPFormulation` — `Params`, `Vars`, `feasible`, `obj`.
- `MILPEquiv F G` — `paramMap`, `fwd`, `bwd`, `fwd_feas`, `bwd_feas`,
  `objMap`, `objMap_mono`, `fwd_obj`, `bwd_obj`.

Every formulation and equivalence file in `dataset/` imports this module
via `import Common`.

## `dataset/`

The dataset itself — MILP problems, their formulations, and equivalence
proofs. See `dataset/README.md` for more information.

## `python/`

Python package `milp_eq_tools` (defined in `python/milp_eq_tools/`) with
modules for loading and manipulating the dataset: `dataset.py`,
`problem.py`, `formulation.py`, `pair.py`, `models.py`. Tests are under
`python/tests/`.

## `scripts/`

Standalone scripts that use `milp_eq_tools`:

- `scripts/gen_solve.py` — generate instance data and solve.
- `scripts/validate.py` — validate dataset integrity.

## Common Workflows

The repo provides a set of skills and agents for working with this dataset. This section outlines how these skills/agents should be utilized for different common workflows.

**Generate a Lean MILP formulation**

1. Identify the relevant source file(s) to read. E.g., the relevant source files for problem 1, formulation e (p1.e) are the problem files in the `dataset/problems/p1` directory and the formulation files in the `dataset/problems/p1/formulations/e` directory. If the user requests generating formulations for a problem, generate all of the problem's formulations.
2. The output file(s) will be `Formulation.lean` in each formulation's subdirectory. E.g., the formulation for p1.e goes in `dataset/problems/p1/formulations/e/Formulation.lean`.
3. Invoke the `milp-formulator` agent with the identified source/output. If generating multiple formulations, invoke multiple agents in parallel.

**Generate Lean MILP equivalence proof**

1. Identify the relevant source file(s) to read. At a minimum, you must read each MILP's `Formulation.lean` file. It may also be useful to read the problem and formulation files. E.g., the relevant source files for proving equivalence between p1.a and p1.b are the problem files in `dataset/problems/p1` and the formulation files `dataset/problems/p1/formulations/a|b`. The formulation subdirectory should contain `Formulation.lean` for both formulations. If it doesn't follow the steps above for generating it.
2. The output file for proving equivalence between problem X and formulations a and b is `dataset/equivalences/pX/a_b.lean`.
3. Invoke the `milp-equivalence-autoformalizer` agent with the identified source/output. If generating multiple formulations, invoke multiple agents in parallel.

**Review existing Lean MILP formulations or equivalence proofs**

1. Identify the relevant file(s) to read. This includes relevant problem files, formulation files, MILP formulation `Formulation.lean` and equivalence proofs `dataset/equivalences/pX/a_b.lean`.
2. Invoke the `milp-reviewer` agent pointing to the relevant file locations. If generating multiple formulations, invoke multiple agents in parallel.
