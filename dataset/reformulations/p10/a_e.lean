import Common
import dataset.problems.p10.formulations.a.Formulation
import dataset.problems.p10.formulations.e.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P10

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P10.a.Params) : P10.e.Params :=
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

/-- Arc variables are non-negative for indices coming from `Fin (p.K + p.N)`. -/
private lemma x_nn (u w : Fin (p.K + p.N)) : 0 ≤ v.x u w := by
  rcases h.hx_bin u w with hh | hh <;> omega

/-- Two distinct outgoing arcs from u sum to at most 1. -/
private lemma out_pair_le (u a b : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x u a + v.x u b ≤ 1 := by
  have hsum : v.x u a + v.x u b ≤ ∑ w : Fin (p.K + p.N), v.x u w := by
    calc v.x u a + v.x u b
        = ∑ w ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w := by
            rw [sum_pair hab]
      _ ≤ ∑ w : Fin (p.K + p.N), v.x u w := by
          apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
          intro w _ _; exact x_nn h u w
  have := h.hout u
  omega

/-- Two distinct incoming arcs to w sum to at most 1. -/
private lemma in_pair_le (a b w : Fin (p.K + p.N)) (hab : a ≠ b) :
    v.x a w + v.x b w ≤ 1 := by
  have hsum : v.x a w + v.x b w ≤ ∑ u : Fin (p.K + p.N), v.x u w := by
    calc v.x a w + v.x b w
        = ∑ u ∈ ({a, b} : Finset (Fin (p.K + p.N))), v.x u w := by
            rw [sum_pair hab]
      _ ≤ ∑ u : Fin (p.K + p.N), v.x u w := by
          apply sum_le_sum_of_subset_of_nonneg (subset_univ _)
          intro u _ _; exact x_nn h u w
  have := h.hin w
  omega

/-- An outgoing arc u→w (u ≠ w) forces the self-loop at u to zero. -/
private lemma arc_forces_self_zero (u w : Fin (p.K + p.N)) (huw : u ≠ w)
    (harc : v.x u w = 1) : v.x u u = 0 := by
  have h1 := out_pair_le h u w u huw.symm
  have h2 := x_nn h u u
  omega

/-- Number of jobs with strictly earlier arrival time than `i`. -/
private noncomputable def rank {N : ℕ} (δ : Fin N → ℝ) (i : Fin N) : ℕ :=
  (univ.filter (fun j : Fin N => δ j < δ i)).card

omit h in
private lemma rank_lt {i j : Fin p.N} (hdlt : v.δ j < v.δ i) :
    rank v.δ j < rank v.δ i := by
  apply card_lt_card
  rw [_root_.ssubset_iff_subset_ne]
  refine ⟨?_, ?_⟩
  · intro k hk
    simp only [mem_filter, mem_univ, true_and] at hk ⊢
    exact lt_trans hk hdlt
  · intro heq
    have : j ∈ univ.filter (fun k : Fin p.N => v.δ k < v.δ i) := by
      simp only [mem_filter, mem_univ, true_and]; exact hdlt
    rw [← heq] at this
    simp only [mem_filter, mem_univ, true_and] at this
    exact lt_irrefl _ this

/-- Helper: if `u : Fin (p.K + p.N)` has value `< p.K`, build truck index. -/
private lemma reach_truck (i : Fin p.N)
    (hi : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0) :
    ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i := by
  haveI := p.hK
  haveI := p.hN
  -- Strong induction on rank.
  suffices hind : ∀ n (i : Fin p.N), rank v.δ i < n →
      v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
          ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0 →
      ∃ k : Fin p.K, p.v k + p.d0 k i ≤ v.δ i from
    hind (rank v.δ i + 1) i (Nat.lt_succ_self _) hi
  intro n
  induction n with
  | zero => intro i hrk; exact absurd hrk (Nat.not_lt_zero _)
  | succ n ih =>
    intro i hrk hacc
    have hKi_lt : p.K + i.val < p.K + p.N := by have := i.isLt; omega
    set Ki : Fin (p.K + p.N) := ⟨p.K + i.val, hKi_lt⟩ with hKi_def
    have hpred : ∃ u : Fin (p.K + p.N), v.x u Ki = 1 := by
      by_contra hall
      push_neg at hall
      have hzero : ∀ u : Fin (p.K + p.N), v.x u Ki = 0 :=
        fun u => (h.hx_bin u Ki).resolve_right (hall u)
      have hsum := h.hin Ki
      simp_rw [hzero] at hsum
      simp at hsum
    obtain ⟨u, hu⟩ := hpred
    have hpred_uniq : ∀ w : Fin (p.K + p.N), w ≠ u → v.x w Ki = 0 := by
      intro w hw
      have hnn := x_nn h w Ki
      have hpair := in_pair_le h w u Ki hw
      omega
    rcases Nat.lt_or_ge u.val p.K with hlt | hge
    · -- Truck case.
      refine ⟨⟨u.val, hlt⟩, ?_⟩
      set k0 : Fin p.K := ⟨u.val, hlt⟩
      have harrival := h.harrival i
      have hk0_eq_u : (⟨k0.val, by have := k0.isLt; omega⟩ : Fin (p.K + p.N)) = u :=
        Fin.ext rfl
      have hsum :
          (∑ l : Fin p.K, (p.d0 l i + p.v l) *
              (v.x ⟨l.val, by have := l.isLt; omega⟩ Ki : ℝ))
            = p.d0 k0 i + p.v k0 := by
        rw [sum_eq_single k0]
        · have hxv : v.x ⟨k0.val, by have := k0.isLt; omega⟩ Ki = 1 := by
            rw [hk0_eq_u]; exact hu
          rw [show (v.x ⟨k0.val, by have := k0.isLt; omega⟩ Ki : ℝ) = 1 from by
            exact_mod_cast hxv]
          ring
        · intro l _ hlk0
          have hTl_ne : (⟨l.val, by have := l.isLt; omega⟩ : Fin (p.K + p.N)) ≠ u := by
            intro he
            apply hlk0
            apply Fin.ext
            show l.val = k0.val
            have : (⟨l.val, by have := l.isLt; omega⟩ : Fin (p.K + p.N)).val = u.val := by
              rw [he]
            simpa using this
          have hzero : v.x ⟨l.val, by have := l.isLt; omega⟩ Ki = 0 :=
            hpred_uniq _ hTl_ne
          rw [show (v.x ⟨l.val, by have := l.isLt; omega⟩ Ki : ℝ) = 0 from by
            exact_mod_cast hzero]
          ring
        · simp
      linarith
    · -- Job case: u.val ≥ p.K, so j := u.val - p.K is a valid Fin p.N.
      have hlt2 : u.val - p.K < p.N := by have := u.isLt; omega
      set j : Fin p.N := ⟨u.val - p.K, hlt2⟩
      have hu_val : u.val = p.K + j.val := by simp [j]; omega
      have hKj_lt : p.K + j.val < p.K + p.N := by have := j.isLt; omega
      set Kj : Fin (p.K + p.N) := ⟨p.K + j.val, hKj_lt⟩
      have hKj_eq_u : Kj = u := Fin.ext hu_val.symm
      have hji : j ≠ i := by
        intro heq
        have hKj_eq_Ki : Kj = Ki := by
          apply Fin.ext; show p.K + j.val = p.K + i.val; rw [heq]
        rw [hKj_eq_u] at hKj_eq_Ki
        have hh : v.x Ki Ki = 1 := by
          have := hu
          rw [hKj_eq_Ki] at this
          exact this
        rw [hacc] at hh; norm_num at hh
      have hji_arc : v.x Kj Ki = 1 := by rw [hKj_eq_u]; exact hu
      have hKj_ne_Ki : Kj ≠ Ki := by
        intro he
        apply hji
        apply Fin.ext
        have : Kj.val = Ki.val := by rw [he]
        have h1 : Kj.val = p.K + j.val := rfl
        have h2 : Ki.val = p.K + i.val := rfl
        rw [h1, h2] at this; omega
      have hj_acc : v.x Kj Kj = 0 :=
        arc_forces_self_zero h Kj Ki hKj_ne_Ki hji_arc
      have hseq_ji := h.hseq j i hji_arc hj_acc
      have hdlt : v.δ j < v.δ i := by
        have hpdjj := p.hd_pos j j
        have hpdji := p.hd_pos j i
        linarith
      have hrk_j : rank v.δ j < rank v.δ i := rank_lt hdlt
      have hrk_jn : rank v.δ j < n := by omega
      obtain ⟨k, hk⟩ := ih j hrk_jn hj_acc
      refine ⟨k, ?_⟩
      have hpdjj := p.hd_pos j j
      have htri0 := p.htri0 k i j
      linarith

/-- Arrival time is at least the earliest start time. -/
private lemma EST_le_delta (i : Fin p.N)
    (hi : v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
            ⟨p.K + i.val, by have := i.isLt; omega⟩ = 0) :
    P10.e.EST (paramMap p) i ≤ v.δ i := by
  haveI := p.hK
  unfold P10.e.EST
  apply max_le
  · show p.τ_min i ≤ v.δ i
    exact h.htw_min i
  · obtain ⟨k, hk⟩ := reach_truck h i hi
    have hle : (univ : Finset (Fin p.K)).inf' univ_nonempty
        (fun l : Fin p.K => (paramMap p).v l + (paramMap p).d0 l i)
          ≤ (paramMap p).v k + (paramMap p).d0 k i :=
      Finset.inf'_le _ (mem_univ k)
    show (univ : Finset (Fin p.K)).inf' univ_nonempty
        (fun l : Fin p.K => (paramMap p).v l + (paramMap p).d0 l i) ≤ v.δ i
    have heq : (paramMap p).v k + (paramMap p).d0 k i = p.v k + p.d0 k i := rfl
    rw [heq] at hle
    linarith

private lemma fwd_hec4 (i k j : Fin p.N)
    (hmem : (i, k, j) ∈ P10.e.Q (paramMap p)) :
    v.x ⟨p.K + i.val, by have := i.isLt; omega⟩
        ⟨p.K + k.val, by have := k.isLt; omega⟩
      + v.x ⟨p.K + k.val, by have := k.isLt; omega⟩
          ⟨p.K + j.val, by have := j.isLt; omega⟩
      + v.x ⟨p.K + k.val, by have := k.isLt; omega⟩
          ⟨p.K + k.val, by have := k.isLt; omega⟩ ≤ 1 := by
  obtain ⟨hik, hkj, _, _, hinfeas⟩ := hmem
  have hKi_lt : p.K + i.val < p.K + p.N := by have := i.isLt; omega
  have hKk_lt : p.K + k.val < p.K + p.N := by have := k.isLt; omega
  have hKj_lt : p.K + j.val < p.K + p.N := by have := j.isLt; omega
  set Ki : Fin (p.K + p.N) := ⟨p.K + i.val, hKi_lt⟩
  set Kk : Fin (p.K + p.N) := ⟨p.K + k.val, hKk_lt⟩
  set Kj : Fin (p.K + p.N) := ⟨p.K + j.val, hKj_lt⟩
  have hKi_ne_Kk : Ki ≠ Kk := by
    intro he
    apply hik; apply Fin.ext
    have : Ki.val = Kk.val := by rw [he]
    show i.val = k.val
    have h1 : Ki.val = p.K + i.val := rfl
    have h2 : Kk.val = p.K + k.val := rfl
    rw [h1, h2] at this; omega
  have hKk_ne_Kj : Kk ≠ Kj := by
    intro he
    apply hkj; apply Fin.ext
    have : Kk.val = Kj.val := by rw [he]
    show k.val = j.val
    have h1 : Kk.val = p.K + k.val := rfl
    have h2 : Kj.val = p.K + j.val := rfl
    rw [h1, h2] at this; omega
  rcases h.hx_bin Kk Kk with hself | hself
  · -- x_{Kk,Kk} = 0.
    by_contra hc; push_neg at hc
    have hin_pair := in_pair_le h Ki Kk Kk hKi_ne_Kk
    have hout_pair := out_pair_le h Kk Kk Kj hKk_ne_Kj
    have hbij_ik := h.hx_bin Ki Kk
    have hbij_kj := h.hx_bin Kk Kj
    have hik_arc : v.x Ki Kk = 1 := by omega
    have hkj_arc : v.x Kk Kj = 1 := by omega
    have hself_i : v.x Ki Ki = 0 :=
      arc_forces_self_zero h Ki Kk hKi_ne_Kk hik_arc
    have hseq1 := h.hseq i k hik_arc hself_i
    have hseq2 := h.hseq k j hkj_arc hself
    have hEST_k := EST_le_delta h k hself
    have hEST_i := EST_le_delta h i hself_i
    have hdk_lb : max (P10.e.EST (paramMap p) k)
        (P10.e.EST (paramMap p) i + p.d i i + p.d i k) ≤ v.δ k := by
      apply max_le hEST_k; linarith
    have htw := h.htw_max j
    have hd_lb : (paramMap p).τ_max j < max (P10.e.EST (paramMap p) k)
        (P10.e.EST (paramMap p) i + (paramMap p).d i i + (paramMap p).d i k)
        + (paramMap p).d k k + (paramMap p).d k j := hinfeas
    have hτeq : (paramMap p).τ_max j = p.τ_max j := rfl
    have hd1 : (paramMap p).d i i = p.d i i := rfl
    have hd2 : (paramMap p).d i k = p.d i k := rfl
    have hd3 : (paramMap p).d k k = p.d k k := rfl
    have hd4 : (paramMap p).d k j = p.d k j := rfl
    rw [hτeq, hd1, hd2, hd3, hd4] at hd_lb
    linarith
  · -- x_{Kk,Kk} = 1.
    have hin_pair := in_pair_le h Ki Kk Kk hKi_ne_Kk
    have hout_pair := out_pair_le h Kk Kk Kj hKk_ne_Kj
    omega

end ForwardHelpers

/-- **P10.a → P10.e**: identity on variables. The new EC4 cut is derived
    from the in/out arc constraints and time-window propagation. -/
private def fwd (p : P10.a.Params) (v : P10.a.Vars p) : P10.e.Vars (paramMap p) :=
  { x := v.x
    δ := v.δ }

private lemma fwd_feas (p : P10.a.Params) (v : P10.a.Vars p)
    (h : P10.a.Feasible p v) :
    P10.e.Feasible (paramMap p) (fwd p v) :=
  { hout      := h.hout
    hin       := h.hin
    harrival  := h.harrival
    hseq      := h.hseq
    htw_min   := h.htw_min
    htw_max   := h.htw_max
    hx_bin    := h.hx_bin
    hec4      := fun i k j hmem => fwd_hec4 h i k j hmem }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/-- **P10.e → P10.a**: identity on variables. Drop the EC4 cut. -/
private def bwd (p : P10.a.Params) (v : P10.e.Vars (paramMap p)) : P10.a.Vars p :=
  { x := v.x
    δ := v.δ }

private lemma bwd_feas (p : P10.a.Params) (v : P10.e.Vars (paramMap p))
    (h : P10.e.Feasible (paramMap p) v) :
    P10.a.Feasible p (bwd p v) :=
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

noncomputable def aEEquiv : MILPReformulation P10.a.formulation P10.e.formulation where
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
