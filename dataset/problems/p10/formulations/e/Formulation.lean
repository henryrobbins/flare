import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P10.Fe

def jobNode (K : ℕ) {N : ℕ} (i : Fin N) : Fin (K + N) :=
  ⟨K + i.val, Nat.add_lt_add_left i.isLt K⟩

def truckNode {K : ℕ} (N : ℕ) (k : Fin K) : Fin (K + N) :=
  Fin.castLE (Nat.le_add_right K N) k

lemma jobNode_injective (K : ℕ) {N : ℕ} : Function.Injective (jobNode K (N := N)) := by
  intro i j h
  simp only [jobNode, Fin.mk.injEq] at h
  exact Fin.ext (Nat.add_left_cancel h)

structure Params (K N : ℕ) where
  d     : Fin N → Fin N → ℝ
  d0    : Fin K → Fin N → ℝ
  dH    : Fin K → Fin N → ℝ
  v     : Fin K → ℝ
  τ_low : Fin N → ℝ
  τ_hi  : Fin N → ℝ
  hd_pos : ∀ i j : Fin N, 0 < d i j
  htri0  : ∀ k i j, d0 k i ≤ d0 k j + d j i
  htri   : ∀ i j m, d i j ≤ d i m + d m j

section

variable {K N : ℕ} [NeZero K] [NeZero N] (p : Params K N)

noncomputable def EST (i : Fin N) : ℝ :=
  max (p.τ_low i) (univ.inf' univ_nonempty (fun k => p.v k + p.d0 k i))

def A_minus : Set (Fin N × Fin N) :=
  {pr | pr.1 ≠ pr.2 ∧ p.τ_hi pr.2 < EST p pr.1 + p.d pr.1 pr.1 + p.d pr.1 pr.2}

/-- Path incompatible triples: i→k→j cannot be completed within j's time window. -/
def Q : Set (Fin N × Fin N × Fin N) :=
  {t | let (i, k, j) := t
    i ≠ k ∧ k ≠ j ∧
    (i, k) ∉ A_minus p ∧ (k, j) ∉ A_minus p ∧
    p.τ_hi j < max (EST p k) (EST p i + p.d i i + p.d i k) + p.d k k + p.d k j}

end

structure Vars (K N : ℕ) where
  x : Fin (K + N) → Fin (K + N) → ℤ
  δ : Fin N → ℝ

structure Feasible {K N : ℕ} [NeZero K] [NeZero N]
    (p : Params K N) (v : Vars K N) : Prop where
  hout     : ∀ u, ∑ w, v.x u w = 1
  hin      : ∀ u, ∑ w, v.x w u = 1
  harrival : ∀ i, v.δ i ≥
    ∑ k, (p.d0 k i + p.v k) * v.x (truckNode N k) (jobNode K i)
  hseq     : ∀ i j : Fin N, i ≠ j →
    v.x (jobNode K i) (jobNode K j) = 1 →
    v.x (jobNode K i) (jobNode K i) = 0 →
    v.δ j ≥ v.δ i + p.d i i + p.d i j
  htw_low  : ∀ i, p.τ_low i ≤ v.δ i
  htw_hi   : ∀ i, v.δ i ≤ p.τ_hi i
  hx_bin   : ∀ u w, v.x u w = 0 ∨ v.x u w = 1
  -- EC4: Forbid sequences of three jobs that violate the time window of the third
  hec4     : ∀ i k j : Fin N, (i, k, j) ∈ Q p →
    v.x (jobNode K i) (jobNode K k) + v.x (jobNode K k) (jobNode K j)
      + v.x (jobNode K k) (jobNode K k) ≤ 1

def obj {K N : ℕ} (p : Params K N) (v : Vars K N) : ℝ :=
  (∑ k, ∑ i, p.d0 k i * (v.x (truckNode N k) (jobNode K i) : ℝ))
  + (∑ i, ∑ j, p.d i j * (v.x (jobNode K i) (jobNode K j) : ℝ))
  + (∑ i, ∑ k, p.dH k i * (v.x (jobNode K i) (truckNode N k) : ℝ))

def formulation (K N : ℕ) [NeZero K] [NeZero N] : MILPFormulation where
  Params   := Params K N
  Vars     := Vars K N
  feasible := Feasible
  obj      := obj

end P10.Fe
