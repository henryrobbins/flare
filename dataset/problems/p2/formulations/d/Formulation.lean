import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P2.d

structure Params where
  M : ℕ  -- number of experiments
  N : ℕ  -- number of resource types
  A : Fin M → ℝ  -- electricity produced by experiment i
  I : Fin N → Fin M → ℝ  -- resource j required for experiment i
  Y : Fin N → ℝ  -- resource j available
  -- Assumptions
  hM : NeZero M
  hN : NeZero N
  -- Implicit Assumptions
  hA_nn : ∀ i, 0 ≤ A i
  hY_nn : ∀ j, 0 ≤ Y j
  hI_nn : ∀ j i, 0 ≤ I j i

structure Vars where
  j : ℕ → ℤ  -- number of times experiment i is conducted
  zed : ℝ  -- auxiliary variable representing total electricity produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Auxiliary variable equals total electricity produced
  hzed : v.zed = ∑ i : Fin p.M, p.A i * (v.j i : ℝ)
  -- Resource usage does not exceed available
  hres : ∀ k : Fin p.N, ∑ i : Fin p.M, p.I k i * (v.j i : ℝ) ≤ p.Y k
  -- [Implicit Constraints]
  hj_nn : ∀ i : Fin p.M, 0 ≤ v.j i

-- Maximize total electricity (via auxiliary variable)
def obj (_ : Params) (v : Vars) : ℝ := -v.zed

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.d
