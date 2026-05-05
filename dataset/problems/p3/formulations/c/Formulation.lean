import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.c

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
  n_0 : Fin p.N → ℤ  -- digit 0 of beaker count i
  n_1 : Fin p.N → ℤ  -- digit 1 of beaker count i

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total liquid used does not exceed available amount
  hliquid : ∑ i : Fin p.N, p.V i * ((v.n_0 i : ℝ) + 10 * (v.n_1 i : ℝ)) ≤ p.Z
  -- Total flour used does not exceed available amount
  hflour  : ∑ i : Fin p.N, p.T i * ((v.n_0 i : ℝ) + 10 * (v.n_1 i : ℝ)) ≤ p.D
  -- Total waste generated does not exceed maximum allowed
  hwaste  : ∑ i : Fin p.N, p.C i * ((v.n_0 i : ℝ) + 10 * (v.n_1 i : ℝ)) ≤ p.E
  -- Digit bounds
  hn0_hi : ∀ i : Fin p.N, v.n_0 i ≤ 9
  hn1_hi : ∀ i : Fin p.N, v.n_1 i ≤ 9
  -- [Implicit Constraints]
  hn0_nn : ∀ i : Fin p.N, 0 ≤ v.n_0 i
  hn1_nn : ∀ i : Fin p.N, 0 ≤ v.n_1 i

-- Maximize total slime produced
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.N, p.X i * ((v.n_0 i : ℝ) + 10 * (v.n_1 i : ℝ)))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.c
