# Agent Skills

FLARE bundles two [Agent
Skills](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
that the agent loads inside the Docker container — one for authoring
Lean 4 MILP formulations and one for authoring `MILPReformulation`
proofs. Each skill ships a `SKILL.md` (the instructions the agent
reads) and a `template.lean` (a scaffold the agent copies into the
working directory).

## `lean-milp-formulation`

Standard for the structure and conventions of Lean 4 MILP formulation
files.

### `SKILL.md`

```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-formulation/SKILL.md
:language: markdown
```

### `template.lean`

```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-formulation/template.lean
:language: lean
```

## `lean-milp-reformulation`

Standard for the structure and conventions of Lean 4 MILP
reformulation proof files.

### `SKILL.md`

```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-reformulation/SKILL.md
:language: markdown
```

### `template.lean`

```{literalinclude} ../src/milp_flare/assets/skills/lean-milp-reformulation/template.lean
:language: lean
```
