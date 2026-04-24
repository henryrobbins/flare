import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P7.d

/-- Column intervals (a, b) with a ≤ j ≤ b, for a given grid size N and column j. -/
def strips_covering (N : ℕ) (j : Fin N) : Finset (Fin N × Fin N) :=
  univ.filter (fun ab => ab.1.val ≤ j.val ∧ j.val ≤ ab.2.val)

structure Params where
  N : ℕ -- grid size (number of rows and columns)
  -- Implicit Assumptions
  hN : NeZero N

structure Vars where
  h : ℕ → ℕ → ℤ  -- hole indicator: 1 if (i,j) is the hole in row i
  x : ℕ → ℕ → ℕ → ℤ  -- strip activation: 1 if row i, columns a..b are covered by same tile
  s : ℕ → ℕ → ℕ → ℤ  -- strip start: 1 if a tile starts at row i for column interval (a,b)
  t : ℕ → ℕ → ℕ → ℤ  -- strip end: 1 if a tile ends at row i for column interval (a,b)

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Each row contains exactly one hole
  hrow : ∀ i : Fin p.N, ∑ j : Fin p.N, v.h i.val j.val = 1
  -- Each column contains exactly one hole
  hcol : ∀ j : Fin p.N, ∑ i : Fin p.N, v.h i.val j.val = 1
  -- Each cell is either a hole or covered by exactly one tile interval
  hcov : ∀ i : Fin p.N, ∀ j : Fin p.N,
    ∑ ab ∈ strips_covering p.N j, v.x i.val ab.1.val ab.2.val + v.h i.val j.val = 1
  -- Top-row flow: strip activity equals strip start at row 0
  htop : ∀ ab : Fin p.N × Fin p.N,
    v.x 0 ab.1.val ab.2.val = v.s 0 ab.1.val ab.2.val
  -- Middle-row flow balance
  hflow : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N, 0 < i.val →
    v.x i.val ab.1.val ab.2.val - v.x (i.val - 1) ab.1.val ab.2.val -
    v.s i.val ab.1.val ab.2.val + v.t (i.val - 1) ab.1.val ab.2.val = 0
  -- Bottom-row flow: strip activity equals strip end at last row
  hbot : ∀ ab : Fin p.N × Fin p.N,
    v.x (p.N - 1) ab.1.val ab.2.val = v.t (p.N - 1) ab.1.val ab.2.val
  hh_bin : ∀ i : Fin p.N, ∀ j : Fin p.N, v.h i.val j.val = 0 ∨ v.h i.val j.val = 1
  hx_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.x i.val ab.1.val ab.2.val = 0 ∨ v.x i.val ab.1.val ab.2.val = 1
  hs_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.s i.val ab.1.val ab.2.val = 0 ∨ v.s i.val ab.1.val ab.2.val = 1
  ht_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.t i.val ab.1.val ab.2.val = 0 ∨ v.t i.val ab.1.val ab.2.val = 1
  -- EC3 (V1): Top-Row Vertical Break
  -- A hole in the first row forces a strip to start in row 1 over the same column span
  htopBreak : ∀ (j : Fin p.N), 1 < p.N →
    v.h 0 j.val ≤ ∑ ab ∈ strips_covering p.N j, v.s 1 ab.1.val ab.2.val

-- Minimize the total number of rectangular tiles used (each tile contributes exactly one start)
def obj (p : Params) (v : Vars) : ℝ :=
  ∑ i : Fin p.N, ∑ ab : Fin p.N × Fin p.N,
    (v.s i.val ab.1.val ab.2.val : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P7.d
