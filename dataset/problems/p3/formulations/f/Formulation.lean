import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.f

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
  n1 : Fin p.N → ℤ  -- part 1 of beaker count i
  n2 : Fin p.N → ℤ  -- part 2 of beaker count i

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total liquid used does not exceed available amount
  hliquid : ∑ i : Fin p.N, p.V i * ((v.n1 i : ℝ) + (v.n2 i : ℝ)) ≤ p.Z
  -- Total flour used does not exceed available amount
  hflour : ∑ i : Fin p.N, p.T i * ((v.n1 i : ℝ) + (v.n2 i : ℝ)) ≤ p.D
  -- Total waste generated does not exceed maximum allowed
  hwaste  : ∑ i : Fin p.N, p.C i * ((v.n1 i : ℝ) + (v.n2 i : ℝ)) ≤ p.E
  -- [Implicit Constraints]
  hn1_nn  : ∀ i : Fin p.N, 0 ≤ v.n1 i
  hn2_nn  : ∀ i : Fin p.N, 0 ≤ v.n2 i

-- Maximize total slime produced
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.N, p.X i * ((v.n1 i : ℝ) + (v.n2 i : ℝ)))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.f
