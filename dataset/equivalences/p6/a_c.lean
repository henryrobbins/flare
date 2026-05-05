import Common
import dataset.problems.p6.formulations.a.Formulation
import dataset.problems.p6.formulations.c.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Data.Finset.Sort
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.c.Params :=
  { n      := p.n
    m      := p.m
    d      := p.d
    u      := p.u
    f      := p.f
    c      := p.c
    hd_pos := p.hd_pos
    hu_nn  := p.hu_nn
    hc_nn  := p.hc_nn
    hf_nn  := p.hf_nn
    hn     := p.hn
    hm     := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd: identity on variables; the EC2 demand-cover cut family is implied by capacity/assignment.
private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.c.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

-- Helper: For a non-increasing (in ℕ val) function g : Fin m → ℝ with g ≥ 0 on
-- all indices and a finset S ⊆ Fin m with |S| ≤ k, `∑_{a ∈ S} g a ≤ ∑_{a.val<k} g a`.
private lemma sum_le_top_k {m : ℕ} (g : Fin m → ℝ)
    (hg_nn : ∀ a, 0 ≤ g a)
    (hg_anti : ∀ a b : Fin m, a ≤ b → g b ≤ g a)
    (S : Finset (Fin m)) (k : ℕ) (hSk : S.card ≤ k) :
    ∑ a ∈ S, g a ≤ ∑ a ∈ univ.filter (fun i : Fin m => i.val < k), g a := by
  set Y := S.card with hY
  -- Re-index S by orderEmbOfFin: get an order embedding f : Fin Y ↪o Fin m.
  let f : Fin Y ↪o Fin m := S.orderEmbOfFin rfl
  -- orderEmbOfFin is strictly monotone; so (f i).val ≥ i.val.
  have hf_ge : ∀ i : Fin Y, (i : ℕ) ≤ (f i).val := by
    intro i
    obtain ⟨i, hi⟩ := i
    induction i with
    | zero => exact Nat.zero_le _
    | succ n ih =>
      have hn : n < Y := Nat.lt_of_succ_lt hi
      have ih1 := ih hn
      have hlt : (⟨n, hn⟩ : Fin Y) < ⟨n+1, hi⟩ := by
        simp [Fin.lt_def]
      have hmono : (f ⟨n, hn⟩ : Fin m) < f ⟨n+1, hi⟩ := f.strictMono hlt
      have hv : (f ⟨n, hn⟩).val < (f ⟨n+1, hi⟩).val := hmono
      -- ih1 : n ≤ (f ⟨n, hn⟩).val, hv : (f ⟨n, hn⟩).val < (f ⟨n+1, hi⟩).val
      have hih : n ≤ (f ⟨n, hn⟩).val := ih1
      show n + 1 ≤ (f ⟨n+1, hi⟩).val
      omega
  -- Rewrite ∑_{a ∈ S} g a using the image of f.
  have himg : Finset.image (⇑f) univ = S := S.image_orderEmbOfFin_univ rfl
  have h1 : ∑ a ∈ S, g a = ∑ i : Fin Y, g (f i) := by
    rw [← himg, Finset.sum_image]
    intros x _ y _ hxy
    exact f.toEmbedding.injective hxy
  rw [h1]
  -- ∑ i : Fin Y, g (f i) ≤ ∑ i : Fin Y, g ⟨i.val, _⟩  (since (f i).val ≥ i.val and g antitone)
  have step1 : ∀ i : Fin Y, g (f i) ≤ g ⟨i.val, by
      have hYm : Y ≤ m := by
        have : S.card ≤ (univ : Finset (Fin m)).card := Finset.card_le_card (subset_univ _)
        simpa using this
      omega⟩ := by
    intro i
    apply hg_anti
    show i.val ≤ _
    exact hf_ge i
  -- Case split: if Y ≤ k and the "top Y" embeds into the "top k".
  have hYm : Y ≤ m := by
    have : S.card ≤ (univ : Finset (Fin m)).card := Finset.card_le_card (subset_univ _)
    simpa using this
  -- Define g' : Fin Y → ℝ  via g'(i) = g ⟨i.val, Nat.lt_of_lt_of_le i.isLt hYm⟩.
  -- Bound: ∑_{i:Fin Y} g(f i) ≤ ∑_{i:Fin Y} g'(i).
  have hle1 : ∑ i : Fin Y, g (f i) ≤ ∑ i : Fin Y,
      g (⟨i.val, Nat.lt_of_lt_of_le i.isLt hYm⟩ : Fin m) := by
    apply Finset.sum_le_sum
    intros i _
    exact step1 i
  -- Now rewrite ∑_{i:Fin Y} g ⟨i.val, _⟩ = ∑_{a ∈ univ.filter (a.val < Y)} g a.
  have hrew : ∑ i : Fin Y, g (⟨i.val, Nat.lt_of_lt_of_le i.isLt hYm⟩ : Fin m)
      = ∑ a ∈ (univ : Finset (Fin m)).filter (fun i : Fin m => i.val < Y), g a := by
    -- Use embedding emb : Fin Y ↪ Fin m via i ↦ ⟨i.val, _⟩.
    let emb : Fin Y ↪ Fin m := ⟨fun i => ⟨i.val, Nat.lt_of_lt_of_le i.isLt hYm⟩, by
      intro a b hab
      apply Fin.ext
      simpa [Fin.ext_iff] using hab⟩
    have : Finset.image emb univ = (univ : Finset (Fin m)).filter (fun i : Fin m => i.val < Y) := by
      ext a
      simp [emb]
      constructor
      · rintro ⟨i, rfl⟩; exact i.isLt
      · intro ha; exact ⟨⟨a.val, ha⟩, Fin.ext rfl⟩
    rw [← this, Finset.sum_image]
    · rfl
    · intro x _ y _ hxy
      apply Fin.ext
      have : (emb x).val = (emb y).val := by rw [hxy]
      simpa [emb] using this
  rw [hrew] at hle1
  refine hle1.trans ?_
  -- ∑_{a.val<Y} g a ≤ ∑_{a.val<k} g a, since Y ≤ k and g ≥ 0.
  apply Finset.sum_le_sum_of_subset_of_nonneg
  · intro a ha
    simp at ha ⊢
    exact Nat.lt_of_lt_of_le ha hSk
  · intro a _ _; exact hg_nn a

-- Helper: sum of nonneg reals `u` over S equals sum of u_j * y_j when S is the
-- set where y_j = 1, with y_j ∈ {0,1}.
private lemma sum_u_y_eq_sum_over_S {m : ℕ} (u : Fin m → ℝ) (z : Fin m → ℤ)
    (hz_bin : ∀ j : Fin m, z j = 0 ∨ z j = 1) :
    ∑ j : Fin m, u j * (z j : ℝ) =
      ∑ j ∈ univ.filter (fun j : Fin m => z j = 1), u j := by
  rw [← Finset.sum_filter_add_sum_filter_not (univ : Finset (Fin m))
      (fun j : Fin m => z j = 1) (fun j => u j * (z j : ℝ))]
  have h1 : ∑ j ∈ (univ : Finset (Fin m)).filter (fun j => z j = 1),
      u j * (z j : ℝ) =
      ∑ j ∈ univ.filter (fun j : Fin m => z j = 1), u j := by
    apply Finset.sum_congr rfl
    intros j hj
    rw [mem_filter] at hj
    rw [hj.2]; simp
  have h2 : ∑ j ∈ (univ : Finset (Fin m)).filter (fun j => ¬ z j = 1),
      u j * (z j : ℝ) = 0 := by
    apply Finset.sum_eq_zero
    intros j hj
    rw [mem_filter] at hj
    rcases hz_bin j with h0 | h1'
    · rw [h0]; simp
    · exact absurd h1' hj.2
  rw [h1, h2, add_zero]

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.c.Feasible (paramMap p) (fwd p v) := by
  refine
    { hassign := h.hassign
      hcap    := h.hcap
      hx_bin  := h.hx_bin
      hy_bin  := h.hy_bin
      hec2    := ?_ }
  intro σ hσ k hk
  -- Key inequality: ∑_i d_i ≤ ∑_j u_j * y_j.
  have hdemand_le : ∑ i : Fin p.n, p.d i ≤ ∑ j : Fin p.m, p.u j * (v.y j : ℝ) := by
    have step1 : ∑ i : Fin p.n, p.d i
        = ∑ i : Fin p.n, ∑ j : Fin p.m, p.d i * (v.x i j : ℝ) := by
      apply Finset.sum_congr rfl
      intros i _
      have hass := h.hassign i
      rw [← Finset.mul_sum]
      have : ((∑ j : Fin p.m, v.x i j : ℤ) : ℝ) = 1 := by
        rw [hass]; simp
      push_cast at this
      rw [this]; ring
    rw [step1]
    rw [Finset.sum_comm]
    apply Finset.sum_le_sum
    intros j _
    exact h.hcap j
  -- Also: ∑_j u_j * y_j = ∑_{a : Fin m} u(σ a) * y(σ a) (re-index).
  have hreindex : ∑ j : Fin p.m, p.u j * (v.y j : ℝ)
      = ∑ a : Fin p.m, p.u (σ a) * (v.y (σ a) : ℝ) :=
    (Equiv.sum_comp σ (fun j : Fin p.m => p.u j * (v.y j : ℝ))).symm
  rw [hreindex] at hdemand_le
  -- Let S = {a : v.y (σ a) = 1}, then ∑_a u(σa) y(σa) = ∑_{a ∈ S} u(σ a).
  have hy_bin' : ∀ a : Fin p.m, v.y (σ a) = 0 ∨ v.y (σ a) = 1 := by
    intro a; exact h.hy_bin (σ a)
  have hsumS := sum_u_y_eq_sum_over_S (m := p.m)
      (fun a : Fin p.m => p.u (σ a))
      (fun a : Fin p.m => v.y (σ a))
      hy_bin'
  rw [hsumS] at hdemand_le
  -- Let S := univ.filter (v.y (σ a) = 1). Compute |S| and bound via sum_le_top_k.
  set S := (univ : Finset (Fin p.m)).filter (fun a : Fin p.m => v.y (σ a) = 1)
    with hSdef
  -- Y := |S| = ∑_j y_j.
  have hY_eq : (S.card : ℤ) = ∑ j : Fin p.m, v.y j := by
    -- Reindex through σ: ∑_j v.y j = ∑_a v.y (σ a).
    have hreidx : (∑ j : Fin p.m, v.y j : ℤ) = ∑ a : Fin p.m, v.y (σ a) :=
      (Equiv.sum_comp σ (fun j : Fin p.m => (v.y j : ℤ))).symm
    rw [hreidx]
    -- Split ∑_a v.y (σ a) by filter.
    rw [← Finset.sum_filter_add_sum_filter_not (univ : Finset (Fin p.m))
      (fun a : Fin p.m => v.y (σ a) = 1) (fun a : Fin p.m => v.y (σ a))]
    have hA : ∑ x ∈ (univ : Finset (Fin p.m)).filter
        (fun a => v.y (σ a) = 1), v.y (σ x) =
        (S.card : ℤ) := by
      have hcard : S.card = ∑ _a ∈ S, (1 : ℤ) := by
        simp [Finset.sum_const, S]
      rw [hcard]
      apply Finset.sum_congr rfl
      intros a ha
      simp at ha
      rw [ha]
    have hB : ∑ x ∈ (univ : Finset (Fin p.m)).filter
        (fun a => ¬ v.y (σ a) = 1), v.y (σ x) = 0 := by
      apply Finset.sum_eq_zero
      intros a ha
      simp at ha
      rcases h.hy_bin (σ a) with h0 | h1
      · exact h0
      · exact absurd h1 ha
    exact (hA ▸ hB ▸ (add_zero _).symm)
  -- Apply sum_le_top_k: S.card ≤ k (we'll derive from ∑ y_j < k assumption via contradiction).
  -- Strategy: contrapositive. Assume k ≤ ∑ y_j is false, i.e. ∑ y_j < k.
  by_contra hlt
  push_neg at hlt
  -- hlt : ∑ j, v.y j < k
  have hcard_lt : S.card < k := by
    have : (S.card : ℤ) < (k : ℤ) := by rw [hY_eq]; exact_mod_cast hlt
    exact_mod_cast this
  have hcard_le : S.card ≤ k := le_of_lt hcard_lt
  -- The antitone function is `fun a => p.u (σ a)` with nonneg values.
  have hg_nn : ∀ a : Fin p.m, 0 ≤ p.u (σ a) := fun a => p.hu_nn (σ a)
  have hg_anti : ∀ a b : Fin p.m, a ≤ b → p.u (σ b) ≤ p.u (σ a) := hσ
  have hbound := sum_le_top_k (fun a : Fin p.m => p.u (σ a)) hg_nn hg_anti S k hcard_le
  -- Now: ∑_{a ∈ S} u(σa) ≤ ∑_{a.val<k} u(σ a) < ∑_i d_i ≤ ∑_{a ∈ S} u(σ a).
  -- The first "≤" is hbound; the "<" is hk; the last "≤" is hdemand_le.
  -- Contradiction.
  have : ∑ a ∈ S, p.u (σ a) < ∑ a ∈ S, p.u (σ a) := by
    calc ∑ a ∈ S, p.u (σ a)
        ≤ ∑ a ∈ (univ : Finset (Fin p.m)).filter (fun i : Fin p.m => i.val < k),
            p.u (σ a) := hbound
      _ < ∑ i : Fin p.n, p.d i := hk
      _ ≤ ∑ a ∈ S, p.u (σ a) := hdemand_le
  exact lt_irrefl _ this

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.c.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.c.Vars (paramMap p))
    (h : P6.c.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  exact
    { hassign := h.hassign
      hcap    := h.hcap
      hx_bin  := h.hx_bin
      hy_bin  := h.hy_bin }

-- ============================================================================
-- § Equivalence Structure
-- ============================================================================

def aCEquiv : MILPReformulation P6.a.formulation P6.c.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
