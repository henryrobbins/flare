import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P18.a

structure Params where
  nI : ℕ  -- number of household clusters
  m : ℕ   -- number of existing hospitals
  M : ℕ   -- total number of hospital sites (|J| = M, |J_0| = m, |J_1| = M - m)
  v : Fin nI → ℝ           -- household cluster population
  a : Fin nI → Fin M → ℤ  -- coverage indicator: 1 if d_ij ≤ S, 0 otherwise
  p : ℤ                    -- maximum number of new hospitals to open
  -- Assumptions
  hmM : m ≤ M  -- existing hospital count bounded by total sites
  ha_bin : ∀ i j, a i j = 0 ∨ a i j = 1
  -- Implicit Assumptions
  hnI : NeZero nI
  hM : NeZero M
  hv_nn : ∀ i, 0 ≤ v i
  hp_nn : 0 ≤ p

structure Vars (P : Params) where
  x : Fin P.M → ℤ  -- hospital open indicator: 1 if hospital j is opened, 0 otherwise
  y : Fin P.nI → ℤ  -- household coverage indicator: 1 if household i is served, 0 otherwise

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Existing hospitals (j ∈ J_0, i.e. j.val < p.m) must remain open
  hexisting : ∀ j : Fin p.M, j.val < p.m → v.x j = 1
  -- At most p new hospitals are opened (j ∈ J_1, i.e. j.val ≥ p.m)
  hnew_cap : ∑ j ∈ univ.filter (fun j : Fin p.M => p.m ≤ j.val), (v.x j : ℤ) ≤ p.p
  -- A household is covered only if at least one open hospital within range exists
  hcover : ∀ i : Fin p.nI, (v.y i : ℤ) ≤ ∑ j : Fin p.M, p.a i j * v.x j
  hx_bin : ∀ j : Fin p.M, v.x j = 0 ∨ v.x j = 1
  hy_bin : ∀ i : Fin p.nI, v.y i = 0 ∨ v.y i = 1

-- Maximize total population coverage
def obj (p : Params) (v : Vars p) : ℝ :=
  -(∑ i : Fin p.nI, p.v i * (v.y i : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P18.a
