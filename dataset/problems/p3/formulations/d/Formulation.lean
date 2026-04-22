import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.d

structure Params where
  N : ℕ           -- number of beakers
  C : Fin N → ℝ  -- waste per beaker i
  E : ℝ           -- max waste allowed
  X : Fin N → ℝ  -- slime per beaker i
  T : Fin N → ℝ  -- flour per beaker i
  D : ℝ           -- flour available
  V : Fin N → ℝ  -- liquid per beaker i
  Z : ℝ           -- liquid available
  -- Implicit Assumptions
  hN    : NeZero N
  hC_nn : ∀ i, 0 ≤ C i
  hX_nn : ∀ i, 0 ≤ X i
  hT_nn : ∀ i, 0 ≤ T i
  hV_nn : ∀ i, 0 ≤ V i

structure Vars where
  n   : ℕ → ℤ  -- number of beakers of type i used
  zed : ℝ       -- auxiliary variable representing total slime produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- zed equals total slime produced
  hzed    : v.zed = ∑ i : Fin p.N, p.X i * v.n i
  -- Total liquid used does not exceed available amount
  hliquid : ∑ i : Fin p.N, p.V i * v.n i ≤ p.Z
  -- Total flour used does not exceed available amount
  hflour  : ∑ i : Fin p.N, p.T i * v.n i ≤ p.D
  -- Total waste generated does not exceed maximum allowed
  hwaste  : ∑ i : Fin p.N, p.C i * v.n i ≤ p.E
  hn_nn   : ∀ i : Fin p.N, 0 ≤ v.n i

-- Maximize zed (total slime produced)
def obj (_ : Params) (v : Vars) : ℝ := -v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.d
