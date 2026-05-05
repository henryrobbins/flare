import Common

namespace P3.i

structure Params where
  C : ℝ  -- heating time per regular pane
  S : ℝ  -- cooling time per regular pane
  P : ℝ  -- heating time per tempered pane
  L : ℝ  -- cooling time per tempered pane
  T : ℝ  -- profit per regular pane
  H : ℝ  -- profit per tempered pane
  D : ℝ  -- max heating machine time per day
  V : ℝ  -- max cooling machine time per day
  -- Implicit Assumptions
  hC_nn : 0 ≤ C
  hS_nn : 0 ≤ S
  hP_nn : 0 ≤ P
  hL_nn : 0 ≤ L
  hT_nn : 0 ≤ T
  hH_nn : 0 ≤ H
  hD_nn : 0 ≤ D
  hV_nn : 0 ≤ V

structure Vars (p : Params) where
  e : ℤ  -- number of regular panes produced
  h : ℤ  -- number of tempered panes produced

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Total heating time does not exceed machine capacity
  hheating : p.C * (v.e : ℝ) + p.P * (v.h : ℝ) ≤ p.D
  -- Total cooling time does not exceed machine capacity
  hcooling : p.S * (v.e : ℝ) + p.L * (v.h : ℝ) ≤ p.V
  -- [Implicit Constraints]
  he_nn : 0 ≤ v.e
  hh_nn : 0 ≤ v.h

-- Objective replaced by optimal solution value
def obj (p : Params) (_ : Vars p) : ℝ := -45

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P3.i
