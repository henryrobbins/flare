import Common

namespace P5.Fh

-- Different problem: wine bottle production
structure Params where
  Q : ℝ  -- min vintage bottles to produce
  D : ℝ  -- volume of one vintage bottle (ml)
  O : ℝ  -- min ratio of regular to vintage bottles
  J : ℝ  -- volume of one regular bottle (ml)
  A : ℝ  -- total wine available (ml)

structure Vars where
  z : ℝ  -- number of regular bottles produced
  g : ℝ  -- number of vintage bottles produced

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Regular bottles ≥ O times vintage bottles
  hratio : p.O * v.g ≤ v.z
  -- At least Q vintage bottles
  hmin_vintage : p.Q ≤ v.g
  -- Total wine usage ≤ available
  hwine : p.D * v.g + p.J * v.z ≤ p.A
  hz_nn : 0 ≤ v.z
  hg_nn : 0 ≤ v.g

-- Maximize total bottles produced
def obj (_ : Params) (v : Vars) : ℝ := -(v.z + v.g)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P5.Fh
