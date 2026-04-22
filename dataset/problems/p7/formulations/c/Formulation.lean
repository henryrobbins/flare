import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P7.Fc

def strips_covering (N : ℕ) (j : Fin N) : Finset (Fin N × Fin N) :=
  univ.filter (fun ab => ab.1.val ≤ j.val ∧ j.val ≤ ab.2.val)

/-- Strips whose left endpoint is immediately right of column j. -/
def strips_starting_after (N : ℕ) (j : Fin N) : Finset (Fin N × Fin N) :=
  univ.filter (fun ab => ab.1.val = j.val + 1)


structure Params (_N : ℕ) where

structure Vars (N : ℕ) where
  h : Fin N → Fin N → ℤ
  x : Fin N → Fin N × Fin N → ℤ
  s : Fin N → Fin N × Fin N → ℤ
  t : Fin N → Fin N × Fin N → ℤ

structure Feasible {N : ℕ} [NeZero N] (_ : Params N) (v : Vars N) : Prop where
  hrow  : ∀ i, ∑ j, v.h i j = 1
  hcol  : ∀ j, ∑ i, v.h i j = 1
  hcov  : ∀ i j, ∑ ab ∈ strips_covering N j, v.x i ab + v.h i j = 1
  htop  : ∀ ab, v.x 0 ab = v.s 0 ab
  hflow : ∀ (i : Fin N) ab, 0 < i.val →
    v.x i ab - v.x ⟨i.val - 1, by omega⟩ ab -
    v.s i ab + v.t ⟨i.val - 1, by omega⟩ ab = 0
  hbot  : ∀ ab,
    v.x ⟨N - 1, by have := NeZero.pos N; omega⟩ ab =
    v.t ⟨N - 1, by have := NeZero.pos N; omega⟩ ab
  hh_bin : ∀ i j, v.h i j = 0 ∨ v.h i j = 1
  hx_bin : ∀ i ab, v.x i ab = 0 ∨ v.x i ab = 1
  hs_bin : ∀ i ab, v.s i ab = 0 ∨ v.s i ab = 1
  ht_bin : ∀ i ab, v.t i ab = 0 ∨ v.t i ab = 1
  -- EC2 (V1): Horizontal-Right Break
  -- A hole forces an interval to start immediately to its right
  hec2 : ∀ i j : Fin N, j.val + 1 < N →
    v.h i j ≤ ∑ ab ∈ strips_starting_after N j, v.s i ab

def obj {N : ℕ} (_ : Params N) (v : Vars N) : ℝ :=
  ∑ i, ∑ ab, (v.s i ab : ℝ)

def formulation (N : ℕ) [NeZero N] : MILPFormulation where
  Params   := Params N
  Vars     := Vars N
  feasible := Feasible
  obj      := obj

end P7.Fc
