import Common

namespace P1.b

structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour

structure Vars where
  s : ℤ  -- number of cash machines
  r : ℤ  -- number of card machines

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Process at least U people per hour
  hpeople : p.U ≤ p.A * v.s + p.K * v.r
  -- Use at most V paper rolls per hour
  hpaper : v.s * p.Y + v.r * p.W ≤ p.V
  -- Card machines ≤ cash machines
  hcard : v.r ≤ v.s
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := v.s + v.r

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.b
