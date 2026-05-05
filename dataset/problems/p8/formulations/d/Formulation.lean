import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic

open BigOperators Finset

namespace P8.d

structure Params where
  n : ℕ  -- number of jobs
  m : ℕ  -- number of machines
  p : Fin n → Fin m → ℝ       -- processing time of op k of job j
  Om : Fin n → Fin m → Fin m  -- machine index for op k of job j
  -- Implicit Assumptions
  hN : NeZero n
  hM : NeZero m
  hp_nn : ∀ j k, 0 ≤ p j k
  hOm_perm : ∀ j : Fin n, Function.Bijective (Om j)

structure Vars (p : Params) where
  S : Fin p.n → Fin p.m → ℝ  -- start time of op k of job j
  Cmax : ℝ        -- makespan

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Technological ordering: op k+1 starts after op k finishes
  hprec : ∀ j : Fin p.n, ∀ k : Fin p.m, (h : k.val + 1 < p.m) →
    v.S j ⟨k.val + 1, h⟩ ≥ v.S j k + p.p j k
  -- Machine non-overlap: two distinct ops on the same machine do not overlap
  -- (encodes Big-M machine non-overlap constraints, y elided)
  hoverlap : ∀ j1 : Fin p.n, ∀ k1 : Fin p.m, ∀ j2 : Fin p.n, ∀ k2 : Fin p.m,
    p.Om j1 k1 = p.Om j2 k2 → (j1, k1) ≠ (j2, k2) →
    v.S j1 k1 + p.p j1 k1 ≤ v.S j2 k2 ∨
    v.S j2 k2 + p.p j2 k2 ≤ v.S j1 k1
  -- Makespan bounds the completion of each job's last operation
  hmakespan : ∀ j : Fin p.n, v.Cmax ≥
    v.S j ⟨p.m - 1, by have := p.hM.out; omega⟩ + p.p j ⟨p.m - 1, by have := p.hM.out; omega⟩
  hS_nn : ∀ j : Fin p.n, ∀ k : Fin p.m, 0 ≤ v.S j k
  hCmax_nn : 0 ≤ v.Cmax
  -- EC3: makespan is at least the total processing time of each job chain
  hec3 : ∀ j : Fin p.n, v.Cmax ≥ ∑ k : Fin p.m, p.p j k

-- Minimize the makespan
def obj (p : Params) (v : Vars p) : ℝ := v.Cmax

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P8.d
