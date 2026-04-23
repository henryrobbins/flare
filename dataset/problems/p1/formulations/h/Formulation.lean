import Common

namespace P1.h

structure Params where
  L : ℝ  -- min containers required
  V : ℝ  -- min oil units to transport
  G : ℝ  -- oil capacity per container
  Y : ℝ  -- oil capacity per truck
  K : ℝ  -- max truck-to-container ratio
  -- Implicit Assumptions
  hL_nn : 0 ≤ L
  hV_nn : 0 ≤ V
  hG_nn : 0 ≤ G
  hY_nn : 0 ≤ Y
  hK_nn : 0 ≤ K

structure Vars where
  c : ℤ  -- number of containers
  p : ℤ  -- number of trucks

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Trucks ≤ K times containers
  htruck_ratio : (v.p : ℝ) ≤ p.K * (v.c : ℝ)
  -- At least L containers required
  hmin_cont : p.L ≤ (v.c : ℝ)
  -- Transport at least V units of oil
  hoil : p.V ≤ p.G * (v.c : ℝ) + p.Y * (v.p : ℝ)
  -- [Implicit Constraints]
  hc_nn : 0 ≤ v.c
  hp_nn : 0 ≤ v.p

-- Minimize total number of containers and trucks
def obj (_ : Params) (v : Vars) : ℝ := (v.c : ℝ) + (v.p : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.h
