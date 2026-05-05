import Common

namespace P1.d

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
  s : ℤ  -- number of cash machines
  r : ℤ  -- number of card machines
  zed : ℝ  -- auxiliary objective variable (= s + r)

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Auxiliary variable equals total machine count
  hzed : v.zed = (v.s : ℝ) + (v.r : ℝ)
  -- Process at least U people per hour
  hpeople : p.U ≤ p.A * (v.s : ℝ) + p.K * (v.r : ℝ)
  -- Use at most V paper rolls per hour
  hpaper : (v.s : ℝ) * p.Y + (v.r : ℝ) * p.W ≤ p.V
  -- Card machines ≤ cash machines
  hcard : v.r ≤ v.s
  -- [Implicit Constraints]
  hs_nn : 0 ≤ v.s
  hr_nn : 0 ≤ v.r

-- Minimize the auxiliary objective variable
def obj (p : Params) (v : Vars p) : ℝ := v.zed

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.d
