import Common

namespace P1.e

structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour
  -- Implicit Assumptions
  hA_nn : 0 ≤ A
  hK_nn : 0 ≤ K
  hY_nn : 0 ≤ Y
  hW_nn : 0 ≤ W
  hU_nn : 0 ≤ U
  hV_nn : 0 ≤ V

structure Vars where
  s : ℤ  -- number of cash machines
  r : ℤ  -- number of card machines
  slack_0 : ℝ  -- slack for throughput constraint
  slack_1 : ℝ  -- slack for card ≤ cash constraint
  slack_2 : ℝ  -- slack for paper rolls constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Throughput equality (slack_0 ≥ 0 makes original ≥ constraint)
  hpeople : p.A * (v.s : ℝ) + p.K * (v.r : ℝ) - v.slack_0 = p.U
  -- Card ≤ cash equality
  hcard : (v.r : ℝ) + v.slack_1 = (v.s : ℝ)
  -- Paper rolls equality
  hpaper : (v.s : ℝ) * p.Y + (v.r : ℝ) * p.W + v.slack_2 = p.V
  -- [Implicit Constraints]
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1
  hslack2_nn : 0 ≤ v.slack_2

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := (v.s : ℝ) + (v.r : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.e
