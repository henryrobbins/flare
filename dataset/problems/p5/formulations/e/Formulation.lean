import Common

namespace P5.e

structure Params where
  Z : ℝ  -- water per bag of subsoil per day
  B : ℝ  -- water per bag of topsoil per day
  D : ℝ  -- max total bags (subsoil + topsoil)
  P : ℝ  -- min topsoil bags
  K : ℝ  -- max topsoil proportion of all bags
  -- Implicit Assumptions
  hZ_nn : 0 ≤ Z
  hB_nn : 0 ≤ B
  hD_nn : 0 ≤ D
  hP_nn : 0 ≤ P
  hK_nn : 0 ≤ K

structure Vars where
  h       : ℤ  -- number of subsoil bags
  d       : ℤ  -- number of topsoil bags
  slack_0 : ℝ  -- slack for topsoil proportion constraint
  slack_1 : ℝ  -- slack for total bags constraint
  slack_2 : ℝ  -- slack for min topsoil constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Topsoil proportion equality with slack
  hprop    : (v.d : ℝ) + v.slack_0 = p.K * ((v.d : ℝ) + v.h)
  -- Total bags equality with slack
  htotal   : (v.h : ℝ) + v.d + v.slack_1 = p.D
  -- Min topsoil equality with slack
  hmin_top : (v.d : ℝ) - v.slack_2 = p.P
  hh_nn : 0 ≤ v.h
  hd_nn : 0 ≤ v.d
  -- Slack non-negativity
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1
  hslack2_nn : 0 ≤ v.slack_2

-- Minimize total water required
def obj (p : Params) (v : Vars) : ℝ := p.Z * (v.h : ℝ) + p.B * v.d

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.e
