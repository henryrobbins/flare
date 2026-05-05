import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.e

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
  hN : NeZero N
  hC_nn : ∀ i, 0 ≤ C i
  hX_nn : ∀ i, 0 ≤ X i
  hT_nn : ∀ i, 0 ≤ T i
  hV_nn : ∀ i, 0 ≤ V i

structure Vars (p : Params) where
  n       : Fin p.N → ℤ  -- number of beakers of type i used
  slack_0 : ℝ       -- slack for liquid constraint
  slack_1 : ℝ       -- slack for flour constraint
  slack_2 : ℝ       -- slack for waste constraint

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total liquid used plus slack equals available amount
  hliquid    : ∑ i : Fin p.N, p.V i * (v.n i : ℝ) + v.slack_0 = p.Z
  -- Total flour used plus slack equals available amount
  hflour     : ∑ i : Fin p.N, p.T i * (v.n i : ℝ) + v.slack_1 = p.D
  -- Total waste generated plus slack equals maximum allowed
  hwaste     : ∑ i : Fin p.N, p.C i * (v.n i : ℝ) + v.slack_2 = p.E
  -- [Implicit Constraints]
  hn_nn      : ∀ i : Fin p.N, 0 ≤ v.n i
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1
  hslack2_nn : 0 ≤ v.slack_2

-- Maximize total slime produced
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.N, p.X i * (v.n i : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.e
