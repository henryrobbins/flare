import Common

namespace P1.f

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

structure Vars (p : Params) where
  s1 : ℤ  -- part 1 of cash machine count
  s2 : ℤ  -- part 2 of cash machine count
  r1 : ℤ  -- part 1 of card machine count
  r2 : ℤ  -- part 2 of card machine count

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Process at least U people per hour
  hpeople : p.U ≤ p.A * ((v.s1 : ℝ) + (v.s2 : ℝ)) + p.K * ((v.r1 : ℝ) + (v.r2 : ℝ))
  -- Use at most V paper rolls per hour
  hpaper : ((v.s1 : ℝ) + (v.s2 : ℝ)) * p.Y + ((v.r1 : ℝ) + (v.r2 : ℝ)) * p.W ≤ p.V
  -- Card machines ≤ cash machines
  hcard : v.r1 + v.r2 ≤ v.s1 + v.s2
  -- [Implicit Constraints]
  hs1_nn : 0 ≤ v.s1
  hs2_nn : 0 ≤ v.s2
  hr1_nn : 0 ≤ v.r1
  hr2_nn : 0 ≤ v.r2

-- Minimize the total number of machines
def obj (p : Params) (v : Vars p) : ℝ := (v.s1 : ℝ) + (v.s2 : ℝ) + (v.r1 : ℝ) + (v.r2 : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.f
