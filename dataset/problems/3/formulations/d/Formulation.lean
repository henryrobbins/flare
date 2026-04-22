import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.Fd

structure Params (n : ℕ) where
  D : ℝ           -- flour available
  Z : ℝ           -- special liquid available
  E : ℝ           -- max waste allowed
  T : Fin n → ℝ  -- flour usage per beaker (not used in constraints)
  V : Fin n → ℝ  -- special liquid usage rate per beaker
  X : Fin n → ℝ  -- slime produced per beaker
  C : Fin n → ℝ  -- waste produced per beaker
  -- Assumptions
  hV_nn : ∀ i, 0 ≤ V i
  hX_nn : ∀ i, 0 ≤ X i
  hC_nn : ∀ i, 0 ≤ C i

structure Vars (n : ℕ) where
  nv  : Fin n → ℝ  -- flour used by beaker type i
  zed : ℝ          -- auxiliary objective variable (= total slime)

structure Feasible {n : ℕ} [NeZero n] (p : Params n) (v : Vars n) : Prop where
  -- Auxiliary variable equals total slime produced
  hzed : v.zed = ∑ i, p.X i * v.nv i
  -- Total liquid used ≤ available
  hliquid : ∑ i, p.V i * v.nv i ≤ p.Z
  -- Total flour used ≤ available
  hflour : ∑ i, v.nv i ≤ p.D
  -- Total waste ≤ allowed
  hwaste : ∑ i, p.C i * v.nv i ≤ p.E
  hnv_nn : ∀ i, 0 ≤ v.nv i

-- Maximize total slime (minimized negation)
def obj (_ : Params n) (v : Vars n) : ℝ := -v.zed

def formulation (n : ℕ) [NeZero n] : MILPFormulation where
  Params   := Params n
  Vars     := Vars n
  feasible := Feasible
  obj      := obj

end P3.Fd
