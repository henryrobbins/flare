import Common

namespace P1.Ff

structure Params where
  A : ℝ  -- cash machine processing rate (people/hour)
  K : ℝ  -- card machine processing rate (people/hour)
  Y : ℝ  -- paper rolls/hour for cash machine
  W : ℝ  -- paper rolls/hour for card machine
  U : ℝ  -- min people processed per hour
  V : ℝ  -- max paper rolls per hour

structure Vars where
  s1 : ℤ  -- part 1 of cash machine count
  s2 : ℤ  -- part 2 of cash machine count
  r1 : ℤ  -- part 1 of card machine count
  r2 : ℤ  -- part 2 of card machine count

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Process at least U people per hour
  hpeople : p.U ≤ p.A * (v.s1 + v.s2) + p.K * (v.r1 + v.r2)
  -- Use at most V paper rolls per hour
  hpaper : (v.s1 + v.s2) * p.Y + (v.r1 + v.r2) * p.W ≤ p.V
  -- Card machines ≤ cash machines
  hcard : v.r1 + v.r2 ≤ v.s1 + v.s2
  hs1_nn : 0 ≤ v.s1
  hs2_nn : 0 ≤ v.s2
  hr1_nn : 0 ≤ v.r1
  hr2_nn : 0 ≤ v.r2

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := v.s1 + v.s2 + v.r1 + v.r2

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.Ff
