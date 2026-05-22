# Agent Skills

`FLARE` utilizes two [Agent Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) for auto-formalization of the `MILPFormulation` (see {fb}`definition </definitions.html#lean-encoding>`) and automated formal proof synthesis (AFPS) of `MILPReformulation` (see {fb}`definition </definitions.html#id2>`). Both skills include a `SKILL.md` and a Lean template `template.lean` with detailed scaffolding instructions.

## `lean-milp-formulation`

Standard structure and conventions for a Lean file defining a MILP formulation `MILPFormulation`.

:::{dropdown} `assets/skills/lean-milp-formulation/SKILL.md`
:icon: markdown
```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-formulation/SKILL.md
:language: markdown
```
:::

:::{dropdown} `assets/skills/lean-milp-formulation/template.lean`
:icon: code
```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-formulation/template.lean
:language: lean
```
:::

## `lean-milp-reformulation`

Standard structure and conventions for a Lean file containing a constructive reformulation proof `MILPReformulation`.

:::{dropdown} `assets/skills/lean-milp-reformulation/SKILL.md`
:icon: markdown
```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-reformulation/SKILL.md
:language: markdown
```
:::

:::{dropdown} `assets/skills/lean-milp-reformulation/template.lean`
:icon: code
```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-reformulation/template.lean
:language: lean
```
:::
