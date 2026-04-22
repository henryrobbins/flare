import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P7.Fa

/-- Strips covering column j: those (a,b) with a ≤ j ≤ b. -/
def strips_covering (N : ℕ) (j : Fin N) : Finset (Fin N × Fin N) :=
  univ.filter (fun ab => ab.1.val ≤ j.val ∧ j.val ≤ ab.2.val)


structure Params (_N : ℕ) where

structure Vars (N : ℕ) where
  h : Fin N → Fin N → ℤ          -- hole indicator
  x : Fin N → Fin N × Fin N → ℤ  -- strip activation
  s : Fin N → Fin N × Fin N → ℤ  -- strip start
  t : Fin N → Fin N × Fin N → ℤ  -- strip end

structure Feasible {N : ℕ} [NeZero N] (_ : Params N) (v : Vars N) : Prop where
  -- One hole per row
  hrow : ∀ i, ∑ j, v.h i j = 1
  -- One hole per column
  hcol : ∀ j, ∑ i, v.h i j = 1
  -- Cell coverage by hole or active strip
  hcov : ∀ i j, ∑ ab ∈ strips_covering N j, v.x i ab + v.h i j = 1
  -- Top-row flow: strip activity equals strip start
  htop : ∀ ab, v.x 0 ab = v.s 0 ab
  -- Middle-row flow balance
  hflow : ∀ (i : Fin N) ab, 0 < i.val →
    v.x i ab - v.x ⟨i.val - 1, by omega⟩ ab -
    v.s i ab + v.t ⟨i.val - 1, by omega⟩ ab = 0
  -- Bottom-row flow: strip activity equals strip end
  hbot : ∀ ab,
    v.x ⟨N - 1, by have := NeZero.pos N; omega⟩ ab =
    v.t ⟨N - 1, by have := NeZero.pos N; omega⟩ ab
  hh_bin : ∀ i j, v.h i j = 0 ∨ v.h i j = 1
  hx_bin : ∀ i ab, v.x i ab = 0 ∨ v.x i ab = 1
  hs_bin : ∀ i ab, v.s i ab = 0 ∨ v.s i ab = 1
  ht_bin : ∀ i ab, v.t i ab = 0 ∨ v.t i ab = 1

-- Minimize the number of rectangles (each contributes exactly one start)
def obj {N : ℕ} (_ : Params N) (v : Vars N) : ℝ :=
  ∑ i, ∑ ab, (v.s i ab : ℝ)

def formulation (N : ℕ) [NeZero N] : MILPFormulation where
  Params   := Params N
  Vars     := Vars N
  feasible := Feasible
  obj      := obj

end P7.Fa
