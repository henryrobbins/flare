---
name: lean-milp-formulation
description: >
  Standard for the structure and conventions of Lean 4 MILP formulation files.
  Use when authoring a new formulation file, reviewing an existing one, or
  modifying one.
---

# Lean MILP Formulation Standard

A MILP formulation file encodes a single mixed-integer linear program as a
`MILPFormulation` value built from four pieces: a `Params` structure for
problem data, a `Vars` structure for decision variables, a `Feasible`
predicate for constraints, and an `obj` function for the objective.

## File structure

Every formulation file contains, in order:

1. Imports (always includes the common MILP definitions module that provides
   `MILPFormulation`, and any targeted Mathlib imports needed by the file).
2. `open BigOperators Finset` if the file uses `∑` or `Finset`.
3. A `namespace` scoped to the formulation (e.g. `P1.a`).
4. `structure Params` — problem data and assumptions on the data.
5. `structure Vars` — decision variables.
6. `structure Feasible (p : Params) (v : Vars) : Prop` — constraints.
7. `def obj (p : Params) (v : Vars) : ℝ` — objective (always ℝ-valued).
8. `def formulation : MILPFormulation` — bundles the above.
9. `end <namespace>`.

See `template.lean` for the canonical layout.

## Type encoding

| Concept                         | Lean encoding                                       |
| ------------------------------- | --------------------------------------------------- |
| Problem dimension               | `ℕ` field of `Params`                               |
| Scalar data                     | `ℝ`                                                 |
| Index set tied to a dimension   | `Fin <dim>` where `<dim>` is a prior `Params` field |
| Continuous variable / parameter | `ℝ`                                                 |
| General integer variable        | `ℤ`                                                 |
| Binary variable                 | `ℤ` with `hvar_bin : ∀ i, var i = 0 ∨ var i = 1`    |
| Vector parameter `b[i]`         | `b : Fin <dim> → ℝ`                                 |
| Matrix parameter `A[i][j]`      | `A : Fin <dim1> → Fin <dim2> → ℝ`                   |
| Vector variable                 | `v : ℕ → ℤ` (or `ℕ → ℝ`); note domain is `ℕ`        |
| Summation `∑`                   | `∑ i : Fin p.<dim>, …` with `open BigOperators`     |

## Formulation Modeling Rules

### No type-level parameters

`Params`, `Vars`, `Feasible`, and `formulation` are all written as plain
(parameter-less) structures / `def`s. Problem dimensions are fields of `Params`,
not type-level arguments. This allows proving equivalences between formulations
with different dimension variables.

### Why `ℕ →` in `Vars`

`Vars` is defined without reference to `Params`, so it cannot mention any
`p.NumFoo`. Vector-valued decision variables therefore use `ℕ → ℤ` /
`ℕ → ℝ` as their type. Every use of such a variable in `Feasible` and
`obj` is scoped to the relevant index slice via `∀ i : Fin p.<dim>, …` or
`∑ i : Fin p.<dim>, …`. The extra (unused) entries at `i ≥ p.<dim>` are
simply not constrained.

### `NeZero` on dimensions

When a dimension must be nonzero for the formulation to make sense, add an
assumption field `hNumFoo : NeZero NumFoo` in the `Params` implicit
assumptions section. Do NOT attach `[NeZero n]` to any structure
(`Params`, `Vars`, `Feasible`) — there are no type-level dimensions.

### Graph topology

For network problems with `nA : ℕ` arcs and `nN : ℕ` nodes (both `Params`
fields), represent graph structure as functions rather than `Finset` edge
lists when possible:

```lean
tail : Fin nA → Fin nN   -- arc tail node
head : Fin nA → Fin nN   -- arc head node
```

Use `Finset.univ.filter` to express flow conservation at specific nodes:

```lean
(univ.filter (fun e => p.tail e = i)).sum (fun e => v.x e k) = …
```

## Naming Conventions

- `Params` fields: use the parameter name exactly as it appears in the source.
- `Vars` fields: use the variable name exactly as it appears in the source.
- `Feasible` fields: `h` + short camel-case constraint name — `hassign`,
  `hcap`, `hbal`, `hprec`, `hoverlap`, `hmtz`, `hflow`, `hdemand`.
- Bound-style suffixes on assumptions and constraints: `_nn` (non-negative),
  `_pos` (positive), `_bin` (binary), `_lo`, `_hi`.

## Formatting Rules

- Single space between a field name and `:`. Do NOT pad field names to
  force column alignment.
- Do NOT wrap inline comments in parentheses (write `-- arc cost`, not
  `-- (arc cost)`).
- If a type is too long to fit on one line with a comment, place the comment
  after the field name on the same line and the type on the next line,
  indented 2 spaces.
- A comment line precedes each constraint or group of like constraints
  with a short description. Sign constraints (non-negativity, positivity)
  do not require a comment.

## Common pitfalls

- **Type-level dimensions.** Do NOT write `structure Params (n : ℕ)`,
  `structure Vars (n : ℕ)`, `Feasible {n : ℕ} [NeZero n] …`, or
  `def formulation (n : ℕ) [NeZero n] : …`. Every structure is
  parameter-less; dimensions are `ℕ` fields of `Params`.
- **`Fin <dim> → …` in `Vars`.** Vector variables use `ℕ → ℤ` / `ℕ → ℝ`.
  `Vars` has no access to `Params` so it cannot mention `p.<dim>`. Scope
  the variable to the real range in `Feasible` and `obj` via
  `∀ i : Fin p.<dim>, …` and `∑ i : Fin p.<dim>, …`.
- **`[NeZero]` attached to a structure.** Nonzero-ness of a dimension is
  an _assumption field_ inside `Params`: `hNumFoo : NeZero NumFoo`. Do
  NOT write `[NeZero n]` anywhere.
- **Binary via `Bool` or `Fin 2`.** Use `ℤ` with an explicit
  `hvar_bin : … = 0 ∨ … = 1` constraint in `Feasible`.
- **Objective not in ℝ.** Even when all data and vars are integer, cast to
  ℝ in `obj`. `MILPFormulation.obj` is ℝ-valued. For maximization,
  negate: `- (∑ …)`.
- **Padding field names.** Single space before `:`, always.
- **Parenthesized inline comments.** Use `-- arc cost`, not `-- (arc cost)`.
- **Missing implicit assumptions.** If a formulation needs a property for
  equivalence (e.g. non-self-loops, triangle inequality), mark it
  explicitly in the `-- Implicit Assumptions` section rather than
  assuming it silently.
