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

Use `ℝ` universally for continuous quantities and `ℤ` universally for integer
quantities. This applies uniformly to parameters and variables. The only `ℕ`
in a formulation is for problem _dimensions_ (sizes used to build `Fin`).

| Concept                       | Lean encoding                                             |
| ----------------------------- | --------------------------------------------------------- |
| Problem dimension             | `ℕ` field of `Params`                                     |
| Index set tied to a dimension | `Fin <dim>` where `<dim>` is a prior `Params` field       |
| Continuous (scalar)           | `ℝ`                                                       |
| Continuous vector `b[i]`      | `b : Fin <dim> → ℝ`                                       |
| Continuous matrix `A[i][j]`   | `A : Fin <dim1> → Fin <dim2> → ℝ`                         |
| Integer (scalar)              | `ℤ`                                                       |
| Integer vector                | `Fin <dim> → ℤ`                                           |
| Binary                        | `ℤ` with `h<name>_bin : ∀ …, <name> … = 0 ∨ <name> … = 1` |
| Non-negative                  | `h<name>_nn : ∀ …, 0 ≤ <name> …`                          |
| Summation `∑`                 | `∑ i : Fin p.<dim>, …` with `open BigOperators`           |

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

### Big-M is forbidden

**Never introduce a big-M constant in a Lean formulation, even if the
source description does.** Big-M is a solver linearization technique; it is not
required in Lean. Instead, rewrite big-M constraints as disjunctions or
conditional equalities on the underlying variables.

**How to rewrite.** The following patterns are examples of big-M patterns in
source MILP formulations and how they should be rewritten in Lean. Another
indicator of big-M is the presence of a parameter named `M` or `bigM` in the
source, or a description of a "sufficiently large constant" in the assumptions.

| Source MILP                                        | Lean `Feasible` field       |
| -------------------------------------------------- | --------------------------- |
| `x ≤ M · y` (binary `y`, `x ≥ 0`)                  | `hlink : v.x = 0 ∨ v.y = 1` |
| `A ≤ B + M·(1 − y)` and `C ≤ D + M·y` (binary `y`) | `hdisj : A ≤ B ∨ C ≤ D`     |

**After rewriting:**

- The big-M parameter (`M`) and its `_pos`/`_nn` assumption MUST NOT appear
  in `Params`.
- Binary indicator variables that exist _solely_ to linearize the
  disjunction (the `y` in `x ≤ M·y` when `y` has no other role) MUST NOT
  appear in `Vars`. Indicators with independent semantics (e.g. `y_j`
  meaning "warehouse `j` is open" with its own opening cost in `obj`)
  stay, but the `M·y` constraint is still rewritten as a disjunction.

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

## Type casting

Decision variables in `Vars` are `ℤ` while `Params` fields and the `obj`
return type are `ℝ`. Lean inserts `ℤ → ℝ` coercions automatically, but
always write them explicitly.

- **In `obj`**: cast the first `ℤ` operand with ascription syntax
  `(v.field : ℝ)`; Lean unifies the rest.
  ```lean
  def obj (_ : Params) (v : Vars) : ℝ := (v.s : ℝ) + v.r
  ```
- **In `Feasible` constraints**: cast each `ℤ` variable that appears
  alongside `ℝ` parameters in an arithmetic expression.
  ```lean
  hpeople : p.A * (v.s : ℝ) + p.K * v.r ≤ p.U
  ```
- **Be consistent within a file.** Do not mix explicit and implicit casts
  across constraints in the same `Feasible` block. If one constraint casts
  `v.s` explicitly, all constraints must.

## Common pitfalls

- **Implicit ℤ→ℝ casts in `obj` and `Feasible`.** Lean coerces silently,
  but the cast must always be written explicitly using `(v.field : ℝ)`.
  Inconsistent casts (explicit in one constraint, implicit in another) make
  equivalence proofs harder to follow and can cause `exact h.hconstraint`
  to fail when the elaborated type does not match the goal.
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
  `h<name>_bin : … = 0 ∨ … = 1` constraint (in `Feasible` for variables, in
  the `Params` assumptions for parameters).
- **Objective not in ℝ.** Even when all data and vars are integer, cast to
  ℝ in `obj`. `MILPFormulation.obj` is ℝ-valued. For maximization,
  negate: `- (∑ …)`.
- **Padding field names.** Single space before `:`, always.
- **Parenthesized inline comments.** Use `-- arc cost`, not `-- (arc cost)`.
- **Missing implicit assumptions.** If a formulation needs a property for
  equivalence (e.g. non-self-loops, triangle inequality), mark it
  explicitly in the `-- Implicit Assumptions` section rather than
  assuming it silently.
