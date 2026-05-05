import Common
import dataset.problems.p10.formulations.a.Formulation
import dataset.problems.p10.formulations.c.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P10

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P10.a.Params) : P10.c.Params :=
  { K := p.K
    N := p.N
    d := p.d
    d0 := p.d0
    dH := p.dH
    v := p.v
    τ_min := p.τ_min
    τ_max := p.τ_max
    hK := p.hK
    hN := p.hN
    hd_pos := p.hd_pos
    htri0 := p.htri0
    htri := p.htri
    hv_nn := p.hv_nn
    hτ_min_nn := p.hτ_min_nn
    hτ_max_nn := p.hτ_max_nn }

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

/-- For `i ≠ j` in `Fin p.N`, the corresponding job nodes (in `Fin (p.K + p.N)`)
    are distinct. -/
private lemma jobNode_ne {p : P10.a.Params} {i j : Fin p.N} (hij : i ≠ j) :
    (⟨p.K + i, by haveI := p.hN; haveI := p.hK; omega⟩ : Fin (p.K + p.N)) ≠
      ⟨p.K + j, by haveI := p.hN; haveI := p.hK; omega⟩ := by
  intro heq
  apply hij
  have hval : p.K + (i : ℕ) = p.K + (j : ℕ) := by
    have := Fin.val_eq_of_eq heq
    simpa using this
  exact Fin.ext (by omega)

/-- If `f a₀ = 1`, every summand `f a` is binary in `{0,1}`,
    and the total sum is `1`, then `f a = 0` for any `a ≠ a₀`. -/
private lemma binary_sum_one_other_zero
    {α : Type*} [Fintype α] [DecidableEq α]
    (f : α → ℤ) (a₀ a : α) (ha : a ≠ a₀)
    (hbin : ∀ b, f b = 0 ∨ f b = 1)
    (hsum : ∑ b, f b = 1)
    (h₀ : f a₀ = 1) : f a = 0 := by
  have hmem : a₀ ∈ (univ : Finset α) := mem_univ _
  have hsplit :
      (∑ b, f b) = f a₀ + ∑ b ∈ univ.erase a₀, f b := by
    rw [← Finset.sum_erase_add _ _ hmem]; ring
  rw [hsplit, h₀] at hsum
  have hzero : ∑ b ∈ univ.erase a₀, f b = 0 := by linarith
  have ha_mem : a ∈ univ.erase a₀ := by simp [Finset.mem_erase, ha]
  have hnn : ∀ b ∈ univ.erase a₀, 0 ≤ f b := by
    intro b _
    rcases hbin b with h0 | h1
    · rw [h0]
    · rw [h1]; exact zero_le_one
  exact (Finset.sum_eq_zero_iff_of_nonneg hnn).mp hzero a ha_mem

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P10.a.Params} {v : P10.a.Vars p} (h : P10.a.Feasible p v)
include h

/-- The EC2 cut: for each mutually-feasible pair (i, j), at most one of the
    arcs (i→j), (j→i), or self-loop (i→i) is taken. -/
private lemma hec2_proof :
    ∀ i j : Fin p.N, (i, j) ∈ P10.c.F₂ (paramMap p) →
      v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
          ⟨p.K + j.val, by have := j.isLt; omega⟩
        + v.x ⟨p.K + j.val, by have := j.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩
        + v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ ≤ 1 := by
  intro i j hmem
  haveI := p.hK
  haveI := p.hN
  obtain ⟨hij, _, _⟩ := hmem
  -- Define the indices in Fin (p.K + p.N)
  set Ki : Fin (p.K + p.N) := ⟨p.K + i, by omega⟩ with hKi_def
  set Kj : Fin (p.K + p.N) := ⟨p.K + j, by omega⟩ with hKj_def
  have hKine : Kj ≠ Ki := jobNode_ne (Ne.symm hij)
  have hxij_bin : v.x Ki Kj = 0 ∨ v.x Ki Kj = 1 := h.hx_bin Ki Kj
  have hxji_bin : v.x Kj Ki = 0 ∨ v.x Kj Ki = 1 := h.hx_bin Kj Ki
  have hxii_bin : v.x Ki Ki = 0 ∨ v.x Ki Ki = 1 := h.hx_bin Ki Ki
  -- Case split on x(K+i, K+i)
  rcases hxii_bin with hxii0 | hxii1
  · -- self-loop = 0; need x(K+i,K+j) + x(K+j,K+i) ≤ 1 (no-2-cycle)
    rw [show v.x Ki Ki = 0 from hxii0]
    by_contra hc
    push_neg at hc
    have hge2 : v.x Ki Kj + v.x Kj Ki ≥ 2 := by linarith
    have hxij1 : v.x Ki Kj = 1 := by
      rcases hxij_bin with h0 | h1
      · rw [h0] at hge2
        rcases hxji_bin with h0' | h1' <;> [rw [h0'] at hge2; rw [h1'] at hge2] <;> linarith
      · exact h1
    have hxji1 : v.x Kj Ki = 1 := by
      rcases hxji_bin with h0 | h1
      · rw [h0] at hge2
        rcases hxij_bin with h0' | h1' <;> [rw [h0'] at hge2; rw [h1'] at hge2] <;> linarith
      · exact h1
    -- self-loop x(K+j,K+j) = 0 follows from x(K+i,K+j) = 1 forcing in
    have hxjj0 : v.x Kj Kj = 0 := by
      have :=
        binary_sum_one_other_zero
          (α := Fin (p.K + p.N)) (fun a : Fin (p.K + p.N) => v.x a Kj) Ki Kj hKine
          (fun b => h.hx_bin b Kj) (h.hin Kj) hxij1
      exact this
    -- Apply hseq i j and hseq j i
    have hseq1 := h.hseq i j hxij1 hxii0
    have hseq2 := h.hseq j i hxji1 hxjj0
    have h_dii := p.hd_pos i i
    have h_dij := p.hd_pos i j
    have h_djj := p.hd_pos j j
    have h_dji := p.hd_pos j i
    linarith
  · -- self-loop = 1; then by hout K+i, x(K+i, K+j) = 0; by hin K+i, x(K+j,K+i)=0
    rw [show v.x Ki Ki = 1 from hxii1]
    have hxij0 : v.x Ki Kj = 0 := by
      have :=
        binary_sum_one_other_zero
          (α := Fin (p.K + p.N)) (fun a : Fin (p.K + p.N) => v.x Ki a) Ki Kj hKine
          (fun b => h.hx_bin Ki b) (h.hout Ki) hxii1
      exact this
    have hxji0 : v.x Kj Ki = 0 := by
      have :=
        binary_sum_one_other_zero
          (α := Fin (p.K + p.N)) (fun a : Fin (p.K + p.N) => v.x a Ki) Ki Kj hKine
          (fun b => h.hx_bin b Ki) (h.hin Ki) hxii1
      exact this
    rw [hxij0, hxji0]; norm_num

end ForwardHelpers

/--
**P10.a → P10.c**: identity on variables. The new EC2 constraint `hec2` is
derived from binarity of x, the in/out flow constraints, and the sequencing
constraint with strictly positive travel times.
-/
private def fwd (p : P10.a.Params) (v : P10.a.Vars p) : P10.c.Vars (paramMap p) :=
  { x := v.x
    δ := v.δ }

private lemma fwd_feas (p : P10.a.Params) (v : P10.a.Vars p)
    (h : P10.a.Feasible p v) :
    P10.c.Feasible (paramMap p) (fwd p v) := by
  exact
    { hout      := h.hout
      hin       := h.hin
      harrival  := h.harrival
      hseq      := h.hseq
      htw_min   := h.htw_min
      htw_max   := h.htw_max
      hx_bin    := h.hx_bin
      hec2      := hec2_proof h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P10.c → P10.a**: identity on variables. Drop the `hec2` constraint.
-/
private def bwd (p : P10.a.Params) (v : P10.c.Vars (paramMap p)) : P10.a.Vars p :=
  { x := v.x
    δ := v.δ }

private lemma bwd_feas (p : P10.a.Params) (v : P10.c.Vars (paramMap p))
    (h : P10.c.Feasible (paramMap p) v) :
    P10.a.Feasible p (bwd p v) := by
  exact
    { hout      := h.hout
      hin       := h.hin
      harrival  := h.harrival
      hseq      := h.hseq
      htw_min   := h.htw_min
      htw_max   := h.htw_max
      hx_bin    := h.hx_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aCReformulation : MILPReformulation P10.a.formulation P10.c.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P10
