import Common

namespace P1.e

structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour

structure Vars where
  s       : ℤ  -- number of cash machines
  r       : ℤ  -- number of card machines
  slack_0 : ℝ  -- slack for throughput constraint
  slack_1 : ℝ  -- slack for card ≤ cash constraint
  slack_2 : ℝ  -- slack for paper rolls constraint

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Throughput equality (slack_0 ≥ 0 makes original ≥ constraint)
  hpeople : p.A * v.s + p.K * v.r - v.slack_0 = p.U
  -- Card ≤ cash equality
  hcard : (v.r : ℝ) + v.slack_1 = v.s
  -- Paper rolls equality
  hpaper : v.s * p.Y + v.r * p.W + v.slack_2 = p.V
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r
  -- [Implicit Constraints]
  -- Slack non-negativity
  hslack0_nn : 0 ≤ v.slack_0
  hslack1_nn : 0 ≤ v.slack_1
  hslack2_nn : 0 ≤ v.slack_2

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := v.s + v.r

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.e
