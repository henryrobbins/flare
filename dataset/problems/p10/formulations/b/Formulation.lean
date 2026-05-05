import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P10.b

structure Params where
  K : ℕ  -- number of trucks
  N : ℕ  -- number of jobs
  d : ℕ → ℕ → ℝ -- job-to-job travel time
  d0 : ℕ → ℕ → ℝ -- depot-to-job travel time
  dH : ℕ → ℕ → ℝ -- job-to-depot travel time
  v : ℕ → ℝ -- truck available time
  τ_min : ℕ → ℝ -- earliest arrival time
  τ_max : ℕ → ℝ -- latest arrival time
  -- Implicit Assumptions
  hK : NeZero K
  hN : NeZero N
  hd_pos : ∀ i j : Fin N, 0 < d i j
  htri0 : ∀ (k : Fin K) (i j : Fin N), d0 k i ≤ d0 k j + d j i
  htri : ∀ i j m : Fin N, d i j ≤ d i m + d m j
  hv_nn : ∀ k : Fin K, 0 ≤ v k
  hτ_min_nn : ∀ i : Fin N, 0 ≤ τ_min i
  hτ_max_nn : ∀ i : Fin N, 0 ≤ τ_max i

/-- Earliest start time for job i. -/
noncomputable def EST (p : Params) (i : Fin p.N) : ℝ :=
  haveI := p.hK
  max (p.τ_min i) (univ.inf' univ_nonempty (fun k : Fin p.K => p.v k + p.d0 k i))

/-- Infeasible arc pairs: j cannot feasibly follow i. -/
def A_minus (p : Params) : Set (Fin p.N × Fin p.N) :=
  {pr | pr.1 ≠ pr.2 ∧ p.τ_max pr.2 < EST p pr.1 + p.d pr.1 pr.1 + p.d pr.1 pr.2}

structure Vars (p : Params) where
  x : Fin (p.K + p.N) → Fin (p.K + p.N) → ℤ -- arc indicator
  δ : Fin p.N → ℝ -- arrival time

structure Feasible (p : Params) (v : Vars p) : Prop where
  -- Each node has exactly one outgoing arc
  hout : ∀ u : Fin (p.K + p.N), ∑ w : Fin (p.K + p.N), v.x u w = 1
  -- Each node has exactly one incoming arc
  hin : ∀ u : Fin (p.K + p.N), ∑ w : Fin (p.K + p.N), v.x w u = 1
  -- Arrival time lower bound at each job
  harrival : ∀ i : Fin p.N,
    v.δ i ≥ ∑ k : Fin p.K, (p.d0 k i + p.v k) *
      (v.x ⟨k.val, by omega⟩ ⟨p.K + i.val, by omega⟩ : ℝ)
  -- Arrival time propagation between consecutive jobs
  hseq : ∀ i j : Fin p.N,
    v.x ⟨p.K + i.val, by omega⟩ ⟨p.K + j.val, by omega⟩ = 1 →
    v.x ⟨p.K + i.val, by omega⟩ ⟨p.K + i.val, by omega⟩ = 0 →
    v.δ j ≥ v.δ i + p.d i i + p.d i j
  -- Time window bounds
  htw_min : ∀ i : Fin p.N, p.τ_min i ≤ v.δ i
  htw_max : ∀ i : Fin p.N, v.δ i ≤ p.τ_max i
  hx_bin : ∀ u w : Fin (p.K + p.N), v.x u w = 0 ∨ v.x u w = 1
  -- EC1: Fix infeasible arcs to zero
  hec1 : ∀ i j : Fin p.N, (i, j) ∈ A_minus p →
    v.x ⟨p.K + i.val, by omega⟩ ⟨p.K + j.val, by omega⟩ = 0

-- Minimize total routing cost
def obj (p : Params) (v : Vars p) : ℝ :=
  (∑ k : Fin p.K, ∑ i : Fin p.N, p.d0 k i *
    (v.x ⟨k.val, by omega⟩ ⟨p.K + i.val, by omega⟩ : ℝ))
  + (∑ i : Fin p.N, ∑ j : Fin p.N, p.d i j *
    (v.x ⟨p.K + i.val, by omega⟩ ⟨p.K + j.val, by omega⟩ : ℝ))
  + (∑ i : Fin p.N, ∑ k : Fin p.K, p.dH k i *
    (v.x ⟨p.K + i.val, by omega⟩ ⟨k.val, by omega⟩ : ℝ))

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P10.b
