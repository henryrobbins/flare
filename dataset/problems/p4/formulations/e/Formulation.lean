import Common

namespace P4.e

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed

structure Vars where
  m       : ℤ  -- number of cars used
  h       : ℤ  -- number of buses used
  slack_0 : ℝ  -- slack for employee transport constraint
  slack_1 : ℝ  -- slack for max buses constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Transport equality with slack (slack_0 ≥ 0 makes original ≥ constraint)
  htransport : v.m * p.K + v.h * p.D - v.slack_0 = p.J
  -- Max buses equality with slack
  hbuses : v.h + v.slack_1 = p.S
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h
  -- Slack non-negativity
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := v.m * p.M + v.h * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.e
