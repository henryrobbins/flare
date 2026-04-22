import Common
import Mathlib.Data.Int.Basic

namespace P1.Fc

structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour

structure Vars where
  s_0 : ℤ  -- digit 0 of cash machine count
  s_1 : ℤ  -- digit 1 of cash machine count
  r_0 : ℤ  -- digit 0 of card machine count
  r_1 : ℤ  -- digit 1 of card machine count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Process at least U people per hour
  hpeople : p.U ≤ p.A * (v.s_0 + 10 * v.s_1 : ℤ) + p.K * (v.r_0 + 10 * v.r_1 : ℤ)
  -- Use at most V paper rolls per hour
  hpaper : (v.s_0 + 10 * v.s_1 : ℤ) * p.Y + (v.r_0 + 10 * v.r_1 : ℤ) * p.W ≤ p.V
  -- Card machines ≤ cash machines
  hcard : v.r_0 + 10 * v.r_1 ≤ v.s_0 + 10 * v.s_1
  -- [Implicit Constraints]
  -- Digit bounds
  hs0_nn : 0 ≤ v.s_0
  hs1_nn : 0 ≤ v.s_1
  hr0_nn : 0 ≤ v.r_0
  hr1_nn : 0 ≤ v.r_1
  hs0_hi : v.s_0 ≤ 9
  hs1_hi : v.s_1 ≤ 9
  hr0_hi : v.r_0 ≤ 9
  hr1_hi : v.r_1 ≤ 9

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ :=
  (v.s_0 + 10 * v.s_1 : ℤ) + (v.r_0 + 10 * v.r_1 : ℤ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.Fc
