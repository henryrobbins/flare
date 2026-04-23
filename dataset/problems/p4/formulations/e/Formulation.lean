import Common

namespace P4.e

structure Params where
  K : ℝ  -- car capacity (employees per car)
  M : ℝ  -- car pollution
  D : ℝ  -- bus capacity (employees per bus)
  O : ℝ  -- bus pollution
  J : ℝ  -- min employees to transport
  S : ℝ  -- max buses allowed
  -- Implicit Assumptions
  hK_nn : 0 ≤ K
  hM_nn : 0 ≤ M
  hD_nn : 0 ≤ D
  hO_nn : 0 ≤ O
  hJ_nn : 0 ≤ J
  hS_nn : 0 ≤ S

structure Vars where
  m : ℤ  -- number of cars used
  h : ℤ  -- number of buses used
  slack_0 : ℝ  -- slack for employee transport constraint
  slack_1 : ℝ  -- slack for max buses constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Transport equality with slack (slack_0 ≥ 0 makes original ≥ constraint)
  htransport : (v.m : ℝ) * p.K + (v.h : ℝ) * p.D - v.slack_0 = p.J
  -- Max buses equality with slack
  hbuses : (v.h : ℝ) + v.slack_1 = p.S
  -- [Implicit Constraints]
  hm_nn : 0 ≤ v.m
  hh_nn : 0 ≤ v.h
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1

-- Minimize total pollution
def obj (p : Params) (v : Vars) : ℝ := (v.m : ℝ) * p.M + (v.h : ℝ) * p.O

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P4.e
