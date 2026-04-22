import Common
import Mathlib.Data.Int.Basic

namespace P5.c

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℝ  -- max total bags (subsoil + topsoil)
  P : ℝ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags

structure Vars where
  h_0 : ℤ  -- digit 0 of subsoil bag count
  h_1 : ℤ  -- digit 1 of subsoil bag count
  d_0 : ℤ  -- digit 0 of topsoil bag count
  d_1 : ℤ  -- digit 1 of topsoil bag count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Topsoil proportion ≤ K
  hprop : (v.d_0 + 10 * v.d_1 : ℤ) ≤
    p.K * ((v.d_0 + 10 * v.d_1 : ℤ) + (v.h_0 + 10 * v.h_1 : ℤ))
  -- Total bags ≤ max
  htotal : (v.h_0 + 10 * v.h_1 : ℤ) + (v.d_0 + 10 * v.d_1 : ℤ) ≤ p.D
  -- At least P topsoil bags
  hmin_top : p.P ≤ (v.d_0 + 10 * v.d_1 : ℤ)
  -- [Implicit Constraints]
  -- Digit bounds
  hh0_nn : 0 ≤ v.h_0
  hh1_nn : 0 ≤ v.h_1
  hd0_nn : 0 ≤ v.d_0
  hd1_nn : 0 ≤ v.d_1
  hh0_hi : v.h_0 ≤ 9
  hh1_hi : v.h_1 ≤ 9
  hd0_hi : v.d_0 ≤ 9
  hd1_hi : v.d_1 ≤ 9

-- Minimize total water required
def obj (p : Params) (v : Vars) : ℝ :=
  p.Z * (v.h_0 + 10 * v.h_1 : ℤ) + p.B * (v.d_0 + 10 * v.d_1 : ℤ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.c
