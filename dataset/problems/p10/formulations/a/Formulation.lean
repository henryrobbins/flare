import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P10.Fa

def jobNode (K : ℕ) {N : ℕ} (i : Fin N) : Fin (K + N) :=
  ⟨K + i.val, Nat.add_lt_add_left i.isLt K⟩

def truckNode {K : ℕ} (N : ℕ) (k : Fin K) : Fin (K + N) :=
  Fin.castLE (Nat.le_add_right K N) k

lemma jobNode_injective (K : ℕ) {N : ℕ} : Function.Injective (jobNode K (N := N)) := by
  intro i j h
  simp only [jobNode, Fin.mk.injEq] at h
  exact Fin.ext (Nat.add_left_cancel h)

structure Params (K N : ℕ) where
  d     : Fin N → Fin N → ℝ  -- job-to-job travel time
  d0    : Fin K → Fin N → ℝ  -- depot-to-job travel time
  dH    : Fin K → Fin N → ℝ  -- job-to-depot travel time
  v     : Fin K → ℝ           -- truck available time
  τ_low : Fin N → ℝ           -- earliest arrival time
  τ_hi  : Fin N → ℝ           -- latest arrival time
  hd_pos : ∀ i j : Fin N, 0 < d i j
  htri0  : ∀ k i j, d0 k i ≤ d0 k j + d j i
  htri   : ∀ i j m, d i j ≤ d i m + d m j

structure Vars (K N : ℕ) where
  x : Fin (K + N) → Fin (K + N) → ℤ  -- arc indicator
  δ : Fin N → ℝ                       -- arrival time

structure Feasible {K N : ℕ} [NeZero K] [NeZero N]
    (p : Params K N) (v : Vars K N) : Prop where
  -- Each node has exactly one outgoing arc
  hout : ∀ u, ∑ w, v.x u w = 1
  -- Each node has exactly one incoming arc
  hin : ∀ u, ∑ w, v.x w u = 1
  -- Arrival time lower bound at each job
  harrival : ∀ i, v.δ i ≥
    ∑ k, (p.d0 k i + p.v k) * v.x (truckNode N k) (jobNode K i)
  -- Arrival time propagation between consecutive jobs
  hseq : ∀ i j : Fin N, i ≠ j →
    v.x (jobNode K i) (jobNode K j) = 1 →
    v.x (jobNode K i) (jobNode K i) = 0 →
    v.δ j ≥ v.δ i + p.d i i + p.d i j
  -- Time window bounds
  htw_low : ∀ i, p.τ_low i ≤ v.δ i
  htw_hi  : ∀ i, v.δ i ≤ p.τ_hi i
  hx_bin  : ∀ u w, v.x u w = 0 ∨ v.x u w = 1

-- Minimize total routing cost
def obj {K N : ℕ} (p : Params K N) (v : Vars K N) : ℝ :=
  (∑ k, ∑ i, p.d0 k i * (v.x (truckNode N k) (jobNode K i) : ℝ))
  + (∑ i, ∑ j, p.d i j * (v.x (jobNode K i) (jobNode K j) : ℝ))
  + (∑ i, ∑ k, p.dH k i * (v.x (jobNode K i) (truckNode N k) : ℝ))

def formulation (K N : ℕ) [NeZero K] [NeZero N] : MILPFormulation where
  Params   := Params K N
  Vars     := Vars K N
  feasible := Feasible
  obj      := obj

end P10.Fa
