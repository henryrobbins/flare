# FLARE

FLARE is an agent-driven verifier for MILP reformulations. Given two
MILP formulations, FLARE drives a coding agent inside a sandboxed
Docker container to (1) auto-formalize each formulation as a Lean 4
`MILPFormulation` and (2) construct a machine-checked
`MILPReformulation` proof connecting them. A post-hoc Lean compile
step decides whether the proof type-checks.

FLARE reuses the same Lean definitions (`MILPFormulation`,
`MILPReformulation`) as
[FormulationBench](https://formulation-bench.henryrobbins.com/) — see
the [Lean reference there](https://formulation-bench.henryrobbins.com/en/latest/lean/index.html)
for the underlying structures.

```{toctree}
:maxdepth: 2
:caption: Contents

installation
user_guide/index
prompts
skills
api/index
```
