import Common
import dataset.problems.p10.formulations.a.Formulation
import dataset.problems.p10.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P10

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P10.a.Params) : P10.b.Params :=
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
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P10.a.Params} {v : P10.a.Vars p} (h : P10.a.Feasible p v)
include h

/-- Arc variables are non-negative. -/
private lemma x_nn (u w : Fin (p.K + p.N)) : 0 ≤ v.x u w := by
  rcases h.hx_bin u w with hh | hh <;> omega

/-- Two distinct outgoing arcs from u sum to at most 1. -/
private lemma out_pair_le (u a b : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x u a + v.x u b ≤ 1 := by
  have hsubset : v.x u a + v.x u b ≤
      ∑ w : Fin (p.K + p.N), v.x u w := by
    calc v.x u a + v.x u b
        = ∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w := by
          rw [sum_pair hab]
      _ ≤ ∑ w : Fin (p.K + p.N), v.x u w := by
          apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
          intro w _ _; exact x_nn h u w
  have hout := h.hout u
  linarith

/-- Two distinct incoming arcs to v sum to at most 1. -/
private lemma in_pair_le (a b w : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x a w + v.x b w ≤ 1 := by
  have hsubset : v.x a w + v.x b w ≤
      ∑ u : Fin (p.K + p.N), v.x u w := by
    calc v.x a w + v.x b w
        = ∑ u ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w := by
          rw [sum_pair hab]
      _ ≤ ∑ u : Fin (p.K + p.N), v.x u w := by
          apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
          intro u _ _; exact x_nn h u w
  have hin := h.hin w
  linarith

/-- An outgoing arc u→t (u ≠ t) forces the self-loop at u to zero. -/
private lemma arc_forces_self_zero (u t : Fin (p.K + p.N)) (hut : u ≠ t)
    (harc : v.x u t = 1) : v.x u u = 0 := by
  have h1 := out_pair_le h u t u hut.symm
  have h2 := x_nn h u u
  omega

/-- Number of jobs with strictly earlier arrival time than i. -/
private noncomputable def rank (δ : Fin p.N → ℝ) (i : Fin p.N) : ℕ :=
  (univ.filter (fun j : Fin p.N => δ j < δ i)).card

omit h in
private lemma rank_lt {i j : Fin p.N} (hdlt : v.δ j < v.δ i) :
    rank (p := p) v.δ j < rank (p := p) v.δ i := by
  apply card_lt_card
  rw [_root_.ssubset_iff_subset_ne]
  refine ⟨?_, ?_⟩
  · intro k hk
    simp only [mem_filter, mem_univ, true_and] at hk ⊢
    exact lt_trans hk hdlt
  · intro heq
    have hmem : j ∈ univ.filter (fun k : Fin p.N => v.δ k < v.δ i) := by
      simp only [mem_filter, mem_univ, true_and]; exact hdlt
    rw [← heq] at hmem
    simp only [mem_filter, mem_univ, true_and] at hmem
    exact lt_irrefl _ hmem

/-- If job `i`'s self-loop is zero, then some truck `k` satisfies
    `v_k + d0(k,i) ≤ δ_i`. -/
private lemma reach_truck (i : Fin p.N)
    (hi : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0) :
    ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i := by
  haveI := p.hK
  haveI := p.hN
  suffices hind : ∀ n (i : Fin p.N), rank (p := p) v.δ i < n →
      v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
          ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0 →
      ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i from
    hind (rank (p := p) v.δ i + 1) i (Nat.lt_succ_self _) hi
  intro n
  induction n with
  | zero => intro i hrk; exact absurd hrk (Nat.not_lt_zero _)
  | succ n ih =>
    intro i hrk hacc
    -- The job node for i, as a Fin (p.K + p.N) element.
    set Ji : Fin (p.K + p.N) := ⟨p.K + i.val, by
      have := i.isLt; omega⟩ with hJi_def
    -- Some predecessor exists.
    have hpred : ∃ u : Fin (p.K + p.N), v.x u Ji = 1 := by
      by_contra hall
      push_neg at hall
      have hzero : ∀ u : Fin (p.K + p.N), v.x u Ji = 0 :=
        fun u => (h.hx_bin u Ji).resolve_right (hall u)
      have hsum := h.hin Ji
      simp_rw [hzero] at hsum
      simp at hsum
    obtain ⟨u, hu⟩ := hpred
    -- The predecessor is unique.
    have hpred_uniq : ∀ w, w ≠ u → v.x w Ji = 0 := by
      intro w hw
      have hnn := x_nn h w Ji
      have hpair := in_pair_le h w u Ji hw
      linarith
    rcases Nat.lt_or_ge u.val p.K with hlt | hge
    · -- Truck case
      set ku : Fin p.K := ⟨u.val, hlt⟩ with hku_def
      refine ⟨ku, ?_⟩
      have harrival := h.harrival i
      have hu_eq : v.x ⟨ku.val, by have := ku.isLt; omega⟩ Ji = 1 := by
        have : (⟨ku.val, by have := ku.isLt; omega⟩ : Fin (p.K + p.N)) = u := Fin.ext rfl
        rw [this]; exact hu
      -- Compute the sum: only k = ku contributes.
      have hsum_eq : ∑ k : Fin p.K, (p.d0 k i + p.v k) *
          (v.x ⟨k.val, by have := k.isLt; omega⟩ Ji : ℝ) =
          p.d0 ku i + p.v ku := by
        rw [sum_eq_single ku]
        · rw [show (v.x ⟨ku.val, by have := ku.isLt; omega⟩ Ji : ℝ) = 1 from by
            exact_mod_cast hu_eq]
          ring
        · intro k _ hkne
          have hkfin : (⟨k.val, by have := k.isLt; omega⟩ : Fin (p.K + p.N)) ≠ u := by
            intro heq
            apply hkne
            apply Fin.ext
            have hval : (⟨k.val, by have := k.isLt; omega⟩ : Fin (p.K + p.N)).val
                = u.val := by rw [heq]
            simpa [hku_def] using hval
          have hzero : v.x ⟨k.val, by have := k.isLt; omega⟩ Ji = 0 :=
            hpred_uniq ⟨k.val, by have := k.isLt; omega⟩ hkfin
          rw [show (v.x ⟨k.val, by have := k.isLt; omega⟩ Ji : ℝ) = 0 from by
            exact_mod_cast hzero]
          ring
        · simp
      -- harrival uses v.x ⟨k.val, _⟩ ⟨p.K + i.val, _⟩ which equals v.x ⟨k.val,_⟩ Ji
      linarith
    · -- Job case: u = jobNode for some j
      have hu_lt : u.val < p.K + p.N := u.isLt
      have hlt2 : u.val - p.K < p.N := by omega
      set j : Fin p.N := ⟨u.val - p.K, hlt2⟩ with hj_def
      have huj_val : u.val = p.K + j.val := by
        show u.val = p.K + (u.val - p.K); omega
      have hu_eq_Jj : u = ⟨p.K + j.val, by have := j.isLt; omega⟩ := Fin.ext huj_val
      have hji : j ≠ i := by
        intro heq
        have hu_eq_Ji : u = Ji := by
          apply Fin.ext
          show u.val = p.K + i.val
          rw [huj_val, heq]
        rw [hu_eq_Ji] at hu
        -- hu : v.x Ji Ji = 1, but hacc says it's 0
        have : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ = 1 := hu
        omega
      have hji_arc : v.x ⟨p.K + j.val, by have := j.isLt; omega⟩
          ⟨p.K + i.val, by have := i.isLt; omega⟩ = 1 := by
        rw [← hu_eq_Jj]; exact hu
      have hne_uJi : u ≠ Ji := by
        intro heq
        have : u.val = Ji.val := by rw [heq]
        rw [huj_val] at this
        have : j.val = i.val := by
          have hJiv : (Ji : ℕ) = p.K + i.val := rfl
          omega
        exact hji (Fin.ext this)
      have hj_acc : v.x ⟨p.K + j.val, by have := j.isLt; omega⟩
          ⟨p.K + j.val, by have := j.isLt; omega⟩ = 0 := by
        have huu : v.x u u = 0 := arc_forces_self_zero h u Ji hne_uJi hu
        rw [hu_eq_Jj] at huu; exact huu
      have hseq_ji := h.hseq j i hji_arc hj_acc
      have hdlt : v.δ j < v.δ i := by
        have hdjj := p.hd_pos j j
        have hdji := p.hd_pos j i
        linarith
      have hrk_j : rank (p := p) v.δ j < rank (p := p) v.δ i := rank_lt hdlt
      have hrk_jn : rank (p := p) v.δ j < n := by omega
      obtain ⟨k, hk⟩ := ih j hrk_jn hj_acc
      refine ⟨k, ?_⟩
      have hdjj := p.hd_pos j j
      have htri := p.htri0 k i j
      linarith

/-- Arrival time is at least the earliest start time. -/
private lemma EST_le_delta (i : Fin p.N)
    (hi : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0) :
    P10.b.EST (paramMap p) i ≤ v.δ i := by
  haveI := p.hK
  -- (paramMap p).N = p.N, but i : Fin p.N — need a cast for EST.
  -- However the function bodies of EST use (paramMap p).τ_min = p.τ_min, etc.
  unfold P10.b.EST
  apply max_le
  · exact h.htw_min i
  · obtain ⟨k, hk⟩ := reach_truck h i hi
    have hinf : univ.inf' univ_nonempty (fun k : Fin p.K => p.v k + p.d0 k i)
        ≤ p.v k + p.d0 k i := inf'_le _ (mem_univ k)
    exact le_trans hinf hk

/-- The EC1 cut is implied by the existing constraints. -/
private lemma hec1_proof : ∀ i j : Fin p.N,
    (i, j) ∈ P10.b.A_minus (paramMap p) →
    v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
        ⟨p.K + j.val, by have := j.isLt; omega⟩ = 0 := by
  intro i j hmem
  obtain ⟨hij, hinfeas⟩ := hmem
  set Ji : Fin (p.K + p.N) := ⟨p.K + i.val, by have := i.isLt; omega⟩ with hJi
  set Jj : Fin (p.K + p.N) := ⟨p.K + j.val, by have := j.isLt; omega⟩ with hJj
  have hne : Ji ≠ Jj := by
    intro heq
    apply hij
    have hval : (Ji : ℕ) = (Jj : ℕ) := congrArg Fin.val heq
    have hkij : p.K + (i : ℕ) = p.K + (j : ℕ) := hval
    have : (i : ℕ) = (j : ℕ) := Nat.add_left_cancel hkij
    exact Fin.ext this
  rcases h.hx_bin Ji Jj with h0 | h1
  · exact h0
  · exfalso
    have hself : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
        ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0 :=
      arc_forces_self_zero h _ _ hne h1
    have hseq := h.hseq i j h1 hself
    have htw := h.htw_max j
    have hest := EST_le_delta h i hself
    have hinfeas' : p.τ_max j < P10.b.EST (paramMap p) i + p.d i i + p.d i j := hinfeas
    linarith

end ForwardHelpers

/--
**P10.a → P10.b**: identity on variables. The new EC1 cut is derived from the
existing time-window and arrival-propagation constraints.
-/
private def fwd (p : P10.a.Params) (v : P10.a.Vars p) : P10.b.Vars (paramMap p) :=
  { x := v.x
    δ := v.δ }

private lemma fwd_feas (p : P10.a.Params) (v : P10.a.Vars p)
    (h : P10.a.Feasible p v) :
    P10.b.Feasible (paramMap p) (fwd p v) := by
  exact
    { hout      := h.hout
      hin       := h.hin
      harrival  := h.harrival
      hseq      := h.hseq
      htw_min   := h.htw_min
      htw_max   := h.htw_max
      hx_bin    := h.hx_bin
      hec1      := hec1_proof h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P10.b → P10.a**: identity on variables. Drop the EC1 constraint.
-/
private def bwd (p : P10.a.Params) (v : P10.b.Vars (paramMap p)) : P10.a.Vars p :=
  { x := v.x
    δ := v.δ }

private lemma bwd_feas (p : P10.a.Params) (v : P10.b.Vars (paramMap p))
    (h : P10.b.Feasible (paramMap p) v) :
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
-- § Equivalence Structure
-- ============================================================================

noncomputable def aBEquiv : MILPReformulation P10.a.formulation P10.b.formulation where
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
