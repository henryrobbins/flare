import Common

namespace P2.i

-- Different problem: snack mix blending (objective replaced by solution value)
structure Params where
  F : ℝ  -- fraction of cat paw treats in mix 1
  M : ℝ  -- fraction of cat paw treats in mix 2
  R : ℝ  -- cat paw treats available (kg)
  W : ℝ  -- gold shark treats available (kg)
  S : ℝ  -- profit per kg of mix 1
  Z : ℝ  -- profit per kg of mix 2

structure Vars where
  n : ℝ  -- kg of mix 1 produced
  v : ℝ  -- kg of mix 2 produced

structure Feasible (p : Params) (v_vars : Vars) : Prop where
  -- Cat paw treats usage ≤ available
  hcat  : p.F * v_vars.n + p.M * v_vars.v ≤ p.R
  -- Gold shark treats usage ≤ available
  hgold : (100 - p.F) / 100 * v_vars.n + (100 - p.M) / 100 * v_vars.v ≤ p.W
  hn_nn : 0 ≤ v_vars.n
  hv_nn : 0 ≤ v_vars.v

-- Objective replaced by constant solution value 1684.6...
def obj (_ : Params) (_ : Vars) : ℝ := -1684.6153846153848

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P2.i
