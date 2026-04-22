import Common

namespace P1.Fi

-- Different problem: oil containers and trucks (objective replaced by solution value)
structure Params where
  L : ℝ  -- min containers required
  V : ℝ  -- min oil units to transport
  G : ℝ  -- oil capacity per container
  Y : ℝ  -- oil capacity per truck
  K : ℝ  -- max truck-to-container ratio

structure Vars where
  c : ℝ  -- number of containers
  p : ℝ  -- number of trucks

structure Feasible (p_params : Params) (v : Vars) : Prop where
  -- Trucks ≤ K times containers
  htruck_ratio : v.p ≤ p_params.K * v.c
  -- At least L containers required
  hmin_cont : p_params.L ≤ v.c
  -- Transport at least V units of oil
  hoil : p_params.V ≤ p_params.G * v.c + p_params.Y * v.p
  hc_nn : 0 ≤ v.c
  hp_nn : 0 ≤ v.p

-- Objective replaced by constant solution value 20.0
def obj (_ : Params) (_ : Vars) : ℝ := 20

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P1.Fi
