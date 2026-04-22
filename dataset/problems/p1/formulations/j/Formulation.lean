import Common

namespace P1.j

-- Missing throughput and card≤cash constraints (invalid/incomplete formulation)
structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour

structure Vars where
  s : ℝ  -- number of cash machines
  r : ℝ  -- number of card machines

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Use at most V paper rolls per hour (only constraint retained)
  hpaper : v.s * p.Y + v.r * p.W ≤ p.V
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := v.s + v.r

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.j
