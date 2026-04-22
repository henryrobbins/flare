import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P3.Fa

-- n = NumBeakers
structure Params (n : ℕ) where
  FlourAvailable              : ℝ           -- flour available
  SpecialLiquidAvailable      : ℝ           -- special liquid available
  MaxWasteAllowed             : ℝ           -- max waste allowed
  FlourUsagePerBeaker         : Fin n → ℝ  -- flour usage per beaker (not used in constraints)
  SpecialLiquidUsagePerBeaker : Fin n → ℝ  -- special liquid usage rate per unit flour for beaker i
  SlimeProducedPerBeaker      : Fin n → ℝ  -- slime produced per unit flour for beaker i
  WasteProducedPerBeaker      : Fin n → ℝ  -- waste produced per unit flour for beaker i
  -- Assumptions
  hSL_nn : ∀ i, 0 ≤ SpecialLiquidUsagePerBeaker i
  hSP_nn : ∀ i, 0 ≤ SlimeProducedPerBeaker i
  hWP_nn : ∀ i, 0 ≤ WasteProducedPerBeaker i

structure Vars (n : ℕ) where
  FlourUsedPerBeaker : Fin n → ℝ  -- flour used by beaker type i

structure Feasible {n : ℕ} [NeZero n] (p : Params n) (v : Vars n) : Prop where
  -- Total flour used ≤ available
  hflour  : ∑ i, v.FlourUsedPerBeaker i ≤ p.FlourAvailable
  -- Total liquid used ≤ available
  hliquid : ∑ i, p.SpecialLiquidUsagePerBeaker i * v.FlourUsedPerBeaker i ≤ p.SpecialLiquidAvailable
  -- Total waste ≤ allowed
  hwaste  : ∑ i, p.WasteProducedPerBeaker i * v.FlourUsedPerBeaker i ≤ p.MaxWasteAllowed
  hx_nn   : ∀ i, 0 ≤ v.FlourUsedPerBeaker i

-- Maximize total slime produced
def obj {n : ℕ} (p : Params n) (v : Vars n) : ℝ :=
  -(∑ i, p.SlimeProducedPerBeaker i * v.FlourUsedPerBeaker i)

def formulation (n : ℕ) [NeZero n] : MILPFormulation where
  Params   := Params n
  Vars     := Vars n
  feasible := Feasible
  obj      := obj

end P3.Fa
