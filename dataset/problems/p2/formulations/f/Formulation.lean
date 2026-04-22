import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.f

structure Params where
  m : ℕ  -- number of experiments
  n : ℕ  -- number of resource types
  A : Fin m → ℝ           -- electricity produced by experiment i
  I : Fin n → Fin m → ℝ  -- resource j required for experiment i
  Y : Fin n → ℝ           -- resource j available
  -- Implicit Assumptions
  hm : NeZero m
  hn : NeZero n
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars where
  j1 : ℕ → ℤ  -- part 1 of experiment count
  j2 : ℕ → ℤ  -- part 2 of experiment count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Resource usage does not exceed available
  hres   : ∀ k : Fin p.n, ∑ i : Fin p.m, p.I k i * (v.j1 i + v.j2 i) ≤ p.Y k
  hj1_nn : ∀ i : Fin p.m, 0 ≤ v.j1 i
  hj2_nn : ∀ i : Fin p.m, 0 ≤ v.j2 i

-- Maximize total electricity produced
def obj (p : Params) (v : Vars) : ℝ :=
  -(∑ i : Fin p.m, p.A i * (v.j1 i + v.j2 i))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P2.f
