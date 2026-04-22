import Common

namespace P2.h

-- Different problem: snack mix blending
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

-- Maximize total profit
def obj (p : Params) (v : Vars) : ℝ := -(p.S * v.n + p.Z * v.v)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P2.h
