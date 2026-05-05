import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P7.e

/-- Column intervals (a, b) with a ≤ j ≤ b, for a given grid size N and column j. -/
def strips_covering (N : ℕ) (j : Fin N) : Finset (Fin N × Fin N) :=
  univ.filter (fun ab => ab.1.val ≤ j.val ∧ j.val ≤ ab.2.val)

structure Params where
  N : ℕ -- grid size (number of rows and columns)
  -- Implicit Assumptions
  hN : NeZero N

structure Vars (p : Params) where
  h : Fin p.N → Fin p.N → ℤ  -- hole indicator: 1 if (i,j) is the hole in row i
  x : Fin p.N → Fin p.N → Fin p.N → ℤ  -- strip activation: 1 if row i, columns a..b are covered by same tile
  s : Fin p.N → Fin p.N → Fin p.N → ℤ  -- strip start: 1 if a tile starts at row i for column interval (a,b)
  t : Fin p.N → Fin p.N → Fin p.N → ℤ  -- strip end: 1 if a tile ends at row i for column interval (a,b)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each row contains exactly one hole
  hrow : ∀ i : Fin p.N, ∑ j : Fin p.N, v.h i j = 1
  -- Each column contains exactly one hole
  hcol : ∀ j : Fin p.N, ∑ i : Fin p.N, v.h i j = 1
  -- Each cell is either a hole or covered by exactly one tile interval
  hcov : ∀ i : Fin p.N, ∀ j : Fin p.N,
    ∑ ab ∈ strips_covering p.N j, v.x i ab.1 ab.2 + v.h i j = 1
  -- Top-row flow: strip activity equals strip start at row 0
  htop : ∀ ab : Fin p.N × Fin p.N,
    haveI := p.hN
    v.x 0 ab.1 ab.2 = v.s 0 ab.1 ab.2
  -- Middle-row flow balance
  hflow : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N, ∀ hi : 0 < i.val,
    v.x i ab.1 ab.2 - v.x ⟨i.val - 1, by omega⟩ ab.1 ab.2 -
    v.s i ab.1 ab.2 + v.t ⟨i.val - 1, by omega⟩ ab.1 ab.2 = 0
  -- Bottom-row flow: strip activity equals strip end at last row
  hbot : ∀ ab : Fin p.N × Fin p.N,
    v.x ⟨p.N - 1, Nat.sub_lt (Nat.pos_of_ne_zero p.hN.out) Nat.one_pos⟩ ab.1 ab.2 =
    v.t ⟨p.N - 1, Nat.sub_lt (Nat.pos_of_ne_zero p.hN.out) Nat.one_pos⟩ ab.1 ab.2
  hh_bin : ∀ i : Fin p.N, ∀ j : Fin p.N, v.h i j = 0 ∨ v.h i j = 1
  hx_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.x i ab.1 ab.2 = 0 ∨ v.x i ab.1 ab.2 = 1
  hs_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.s i ab.1 ab.2 = 0 ∨ v.s i ab.1 ab.2 = 1
  ht_bin : ∀ i : Fin p.N, ∀ ab : Fin p.N × Fin p.N,
    v.t i ab.1 ab.2 = 0 ∨ v.t i ab.1 ab.2 = 1
  -- EC4 (V1): Bottom-Row Vertical Break
  -- A hole in the last row forces a strip to end in row N-2 over the same column span
  hbotBreak : ∀ (j : Fin p.N), ∀ hN_gt : 1 < p.N,
    v.h ⟨p.N - 1, Nat.sub_lt (Nat.pos_of_ne_zero p.hN.out) Nat.one_pos⟩ j ≤
    ∑ ab ∈ strips_covering p.N j, v.t ⟨p.N - 2, by omega⟩ ab.1 ab.2

-- Minimize the total number of rectangular tiles used (each tile contributes exactly one start)
def obj (p : Params) (v : Vars p) : ℝ :=
  ∑ i : Fin p.N, ∑ ab : Fin p.N × Fin p.N,
    (v.s i ab.1 ab.2 : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P7.e
