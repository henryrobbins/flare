import Common

namespace P5.i

structure Params where
  Q : ℝ  -- min vintage bottles to produce
  D : ℝ  -- volume of one vintage bottle (ml)
  O : ℝ  -- min ratio of regular to vintage bottles
  J : ℝ  -- volume of one regular bottle (ml)
  A : ℝ  -- total wine available (ml)
  -- Implicit Assumptions
  hQ_nn : 0 ≤ Q
  hD_nn : 0 ≤ D
  hO_nn : 0 ≤ O
  hJ_nn : 0 ≤ J
  hA_nn : 0 ≤ A

structure Vars where
  z : ℤ  -- number of regular bottles produced
  g : ℤ  -- number of vintage bottles produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Regular bottles ≥ O times vintage bottles
  hratio : p.O * (v.g : ℝ) ≤ (v.z : ℝ)
  -- At least Q vintage bottles
  hmin_vintage : p.Q ≤ (v.g : ℝ)
  -- Total wine usage ≤ available
  hwine : p.D * (v.g : ℝ) + p.J * (v.z : ℝ) ≤ p.A
  hz_nn : 0 ≤ v.z
  hg_nn : 0 ≤ v.g

-- Objective replaced by optimal solution value
def obj (_ : Params) (_ : Vars) : ℝ := -300

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.i
