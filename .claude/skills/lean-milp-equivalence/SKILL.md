---
name: lean-milp-equivalence
description: >
  Standard for the structure and conventions of Lean 4 MILP equivalence files.
  Use when authoring a new equivalence file, reviewing an existing one, or
  modifying one.
---

# Lean MILP Equivalence Standard

An equivalence proof file shows that two MILP formulations `A` and `B` are
equivalent under the project's `MILPEquiv` structure: it produces a
parameter map `A.Params → B.Params`, mutually inverse feasibility-preserving
variable maps, and a monotone objective map that makes forward and backward
objective diagrams commute.

## `MILPEquiv` at a glance

The project's common MILP module defines `MILPEquiv F G` with fields:

- `paramMap    : F.Params → G.Params`
- `fwd         : F.Params → F.Vars → G.Vars`
- `bwd         : F.Params → G.Vars → F.Vars`
- `fwd_feas    : ∀ p v, F.feasible p v → G.feasible (paramMap p) (fwd p v)`
- `bwd_feas    : ∀ p v, G.feasible (paramMap p) v → F.feasible p (bwd p v)`
- `objMap      : ℝ → ℝ`
- `objMap_mono : Monotone objMap`
- `fwd_obj     : ∀ p v, F.feasible p v → G.obj (paramMap p) (fwd p v) = objMap (F.obj p v)`
- `bwd_obj     : ∀ p v, G.feasible (paramMap p) v → G.obj (paramMap p) v = objMap (F.obj p (bwd p v))`

The semantic requirement is **pointwise**: feasibility and objective
preservation for _all_ feasible solutions — not merely equal optima.

## File structure

Every equivalence file contains, in order:

1. Imports: the common MILP module (providing `MILPEquiv`), both
   formulations `A` and `B`, and targeted Mathlib imports.
2. `open BigOperators Finset` if the proofs use `∑` or `Finset`.
3. A `namespace` matching the shared problem scope (e.g. `P1`, `General.TSP`).
4. Optional helper-lemma section (lemmas local to this equivalence).
5. Optional `paramMap` definition (inline in the structure if trivial).
6. Optional forward-helpers section + `fwd` and `fwd_feas`.
7. Optional backward-helpers section + `bwd` and `bwd_feas`.
8. Optional objective-mapping section + `objMap`, `objMap_mono`, and
   `fwd_obj` / `bwd_obj`.
9. The final `MILPEquiv` `def`.
10. `end <namespace>`.

See `template.lean` for the canonical layout.

## Naming conventions

- Equivalence `def` name: camelCase, `<formA><FormB>Equiv`
  (e.g. `originalCEquiv`, `scfMcfEquiv`). Match the file name.
- Helper defs/lemmas: `private`. All helpers live in the equivalence file
  itself — there is no shared-lemmas module.
- Canonical names: `paramMap`, `fwd`, `bwd`, `fwd_feas`, `bwd_feas`,
  `objMap`, `objMap_mono`, `fwd_obj`, `bwd_obj`.

## When to inline vs. extract

Each of `paramMap`, `fwd`/`fwd_feas`, `bwd`/`bwd_feas`, and the objective
mapping has a dedicated optional section. Use these rules:

- **Inline in the `MILPEquiv` structure** when the body is a single line or
  a trivial expression. Examples: `paramMap := id` (but see the pitfall
  below), `paramMap p := { c := p.c }`, `fwd _ v := { a := v.x }`,
  `fwd_obj _ _ _ := rfl`, `objMap := id`, `objMap_mono := monotone_id`.
- **Extract to a `private def`/`lemma` above the structure** when the body
  is multi-line or the proof is non-trivial.
- Do NOT leave empty section headers. If a section is not needed, remove
  the header along with its contents.

## Helper sections (`ForwardHelpers` / `BackwardHelpers`)

Only include a `section ForwardHelpers` (resp. `BackwardHelpers`) block
when there are `private` helper lemmas or definitions that depend on a
feasible solution. Inside:

- Introduce `Params` and `Vars` as **implicit** parameters (e.g.
  `{p : <A>.Params} {v : <A>.Vars}`). Do NOT introduce any separate
  dimension parameters — dimensions live as fields of `p`.
- Introduce the feasibility hypothesis as an **explicit** parameter `h`,
  then `include h` so Lean uses it.

## Equivalence files are self-contained

Every equivalence file contains all of its own helper lemmas and
definitions. Equivalence files do not import each other, and there is no
shared-lemmas module. If two equivalence files need the same lemma,
duplicate it (each as `private`) rather than introducing a shared module.

## Stray-content rules

- No additional `/-! … -/` doc-comment blocks after the module header.
  Proof reasoning goes in tactic-line `-- …` comments inside the proof
  body.
- No leftover `sorry` in a finalized file.
- No leftover `/- NOTE … -/` template comments.
- No empty section headers — delete the header along with the contents.

## Common pitfalls

These patterns cause the most wasted iterations; check each one before
finalizing a file.

### `paramMap := id` when namespaces differ

`A.Params` and `B.Params` from different namespaces are **distinct types**
even when structurally identical. `id` will not typecheck. Always write an
explicit field-by-field `paramMap`, even when it looks trivial:

```lean
paramMap p := { c := p.c, d := p.d }
```

### Claim strength mismatch

`MILPEquiv` is pointwise. If the source claims only "same optimal value",
the hard direction may be intractable under `MILPEquiv`. Identify this up
front and decide whether to leave `sorry`, restrict the claim, or change
formulations.

### `|>.field` in type positions

`|>.` pipe-chained accessor notation is **invalid in Lean 4 type
annotations** (lemma return types, `show` targets). Use explicit
parenthesization:

```lean
-- WRONG (parse error):
… : <A>.formulation |>.obj (paramMap p) (fwd p v) = … := by

-- CORRECT:
… : (<A>.formulation).obj (paramMap p) (fwd p v) = … := by
```

### Cast across sums

`↑(∑ i, f i)` is **not definitionally equal** to `∑ i, ↑(f i)`; `show` and
`rfl` both fail. Use `push_cast`, `simp_rw [Int.cast_sum]`, or
`Finset.cast_sum`:

```lean
-- FAILS:
show ↑(∑ j, v.y i j) = ↑(v.y i)

-- WORKS:
simp_rw [Int.cast_sum]  -- or push_cast; ring
```

### Dimension nonzero-ness comes from `Params`

Dimensions are `Params` fields (`NumFoo : ℕ`) and their non-emptiness is
an assumption field (`hNumFoo : NeZero NumFoo`). To use `Fintype`
instances on `Fin p.NumFoo` inside a helper, bring the `NeZero` into
scope from the feasibility / params hypothesis — e.g. `haveI := p.hNumFoo`.
Do NOT reintroduce dimensions as standalone `{n : ℕ} [NeZero n]` binders
in helper lemmas.

### `linarith` across cast boundaries

When `linarith` must reason across `ℤ → ℝ` or `ℕ → ℤ`, it often fails.
Break the chain with explicit `have` steps using `norm_cast` / `push_cast`
before handing to `linarith`.

### `rewrite` interaction with `if`

`rw [eq]` that substitutes inside the condition of an `if h_cond then …`
changes `h_cond`, so a later `rw` looking for the original pattern fails.
Scope such rewrites to specific subgoals.

### `noncomputable` for structure extraction

Mark `fwd` / `bwd` / the whole section `noncomputable` when a direction
uses `Classical.choice` or extracts structure (tour order, permutation)
from a feasible solution. Prefer deterministic selections (e.g. minimum
index via `LinearOrder` on `Fin n`) when possible — cleaner and avoids
`noncomputable`.
