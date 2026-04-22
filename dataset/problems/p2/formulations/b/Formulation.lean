import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic

open BigOperators Finset

namespace P2.b

structure Params where
  m : ℕ  -- number of trials
  n : ℕ  -- number of resource types
  A : Fin m → ℝ  -- electrical energy generated from trial i
  I : Fin n → Fin m → ℝ  -- resource j quantity needed for experiment i
  Y : Fin n → ℝ  -- quantity of resource j that is accessible
  -- Implicit Assumptions
  hm : NeZero m
  hn : NeZero n
  hA_nn : ∀ i, 0 ≤ A i
  hI_nn : ∀ j i, 0 ≤ I j i
  hY_nn : ∀ j, 0 ≤ Y j

structure Vars where
  j : ℕ → ℤ  -- frequency at which each experiment is performed

structure Feasible (p : Params) (v : Vars) : Prop where
  -- For each resource, total required across all experiments does not exceed available amount
  hres  : ∀ i : Fin p.n, ∑ k : Fin p.m, p.I i k * v.j k ≤ p.Y i
  hj_nn : ∀ i : Fin p.m, 0 ≤ v.j i

-- Maximize total electrical output
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.m, p.A i * v.j i)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P2.b
