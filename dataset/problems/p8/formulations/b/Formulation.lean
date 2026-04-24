import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic

open BigOperators Finset

namespace P8.b

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

structure Vars where
  S : ℕ → ℕ → ℝ  -- start time of op k of job j
  Cmax : ℝ        -- makespan

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Technological ordering: op k+1 starts after op k finishes
  hprec : ∀ j : Fin p.n, ∀ k : Fin p.m, (h : k.val + 1 < p.m) →
    v.S j.val (k.val + 1) ≥ v.S j.val k.val + p.p j k
  -- Machine non-overlap: two distinct ops on the same machine do not overlap
  -- (encodes Big-M machine non-overlap constraints, y elided)
  hoverlap : ∀ j1 : Fin p.n, ∀ k1 : Fin p.m, ∀ j2 : Fin p.n, ∀ k2 : Fin p.m,
    p.Om j1 k1 = p.Om j2 k2 → (j1, k1) ≠ (j2, k2) →
    v.S j1.val k1.val + p.p j1 k1 ≤ v.S j2.val k2.val ∨
    v.S j2.val k2.val + p.p j2 k2 ≤ v.S j1.val k1.val
  -- Makespan bounds the completion of each job's last operation
  hmakespan : ∀ j : Fin p.n, v.Cmax ≥
    v.S j.val (p.m - 1) + p.p j ⟨p.m - 1, by have := p.hM.out; omega⟩
  hS_nn : ∀ j : Fin p.n, ∀ k : Fin p.m, 0 ≤ v.S j.val k.val
  hCmax_nn : 0 ≤ v.Cmax
  -- EC1: makespan is at least the average total processing time per machine
  hec1 : v.Cmax ≥ (∑ j : Fin p.n, ∑ k : Fin p.m, p.p j k) / (p.m : ℝ)

-- Minimize the makespan
def obj (_ : Params) (v : Vars) : ℝ := v.Cmax

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P8.b
