import Common

namespace P1.j

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

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Use at most V paper rolls per hour (only constraint retained)
  hpaper : (v.s : ℝ) * p.Y + (v.r : ℝ) * p.W ≤ p.V
  -- [Implicit Constraints]
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r

-- Minimize the total number of machines
def obj (_ : Params) (v : Vars) : ℝ := (v.s : ℝ) + (v.r : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.j
