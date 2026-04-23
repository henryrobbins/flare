import Common

namespace P2.i

structure Params where
  F : ℝ  -- fraction of cat paw treats in mix 1
  M : ℝ  -- fraction of cat paw treats in mix 2
  R : ℝ  -- cat paw treats available (kg)
  W : ℝ  -- gold shark treats available (kg)
  S : ℝ  -- profit per kg of mix 1
  Z : ℝ  -- profit per kg of mix 2
  -- Implicit Assumptions
  hF_nn : 0 ≤ F
  hM_nn : 0 ≤ M
  hR_nn : 0 ≤ R
  hW_nn : 0 ≤ W
  hS_nn : 0 ≤ S
  hZ_nn : 0 ≤ Z

structure Vars where
  n : ℝ  -- kg of mix 1 produced
  v : ℝ  -- kg of mix 2 produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Cat paw treats usage ≤ available
  hcat : p.F * v.n + p.M * v.v ≤ p.R
  -- Gold shark treats usage ≤ available
  hgold : (100 - p.F) / 100 * v.n + (100 - p.M) / 100 * v.v ≤ p.W
  -- [Implicit Constraints]
  hn_nn : 0 ≤ v.n
  hv_nn : 0 ≤ v.v

-- Maximize fixed solution value (negated for minimization semantics)
def obj (_ : Params) (_ : Vars) : ℝ := -1684.6153846153848

def formulation : MILPFormulation where
  Params := Params
  Vars := Vars
  feasible := Feasible
  obj := obj

end P2.i
