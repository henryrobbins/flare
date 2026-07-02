import Common
import problems.p6.formulations.a.Formulation
import problems.p6.formulations.d.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P6

-- ============================================================================
-- § Helper Lemmas
-- ============================================================================

-- Cardinality of the initial segment filter on `Fin N`.
private lemma card_lt_filter {N : ℕ} (k : ℕ) (hk : k ≤ N) :
    ((univ : Finset (Fin N)).filter (fun i : Fin N => i.val < k)).card = k := by
  classical
  have heq : (univ : Finset (Fin N)).filter (fun i : Fin N => i.val < k) =
      (Finset.range k).attachFin (fun i hi => lt_of_lt_of_le (Finset.mem_range.mp hi) hk) := by
    ext ⟨i, hi⟩
    simp [Finset.mem_attachFin, Finset.mem_range]
  rw [heq]
  simp

-- For any antitone function on `Fin N` and any subset `S`, sum over `S` ≤ sum over top S.card.
private lemma sum_le_sum_top_of_antitone {N : ℕ} (f : Fin N → ℝ)
    (hf : ∀ a b : Fin N, a ≤ b → f b ≤ f a)
    (S : Finset (Fin N)) :
    ∑ a ∈ S, f a ≤
      ∑ a ∈ (univ : Finset (Fin N)).filter (fun i : Fin N => i.val < S.card), f a := by
  classical
  set T : Finset (Fin N) :=
    (univ : Finset (Fin N)).filter (fun i : Fin N => i.val < S.card) with hTdef
  have hScard_le_N : S.card ≤ N := by
    have := S.card_le_univ
    simpa [Fintype.card_fin] using this
  have hTcard : T.card = S.card := card_lt_filter S.card hScard_le_N
  have hS_split : ∑ a ∈ S, f a = ∑ a ∈ S ∩ T, f a + ∑ a ∈ S \ T, f a :=
    (Finset.sum_inter_add_sum_diff S T f).symm
  have hT_split : ∑ a ∈ T, f a = ∑ a ∈ S ∩ T, f a + ∑ a ∈ T \ S, f a := by
    rw [← Finset.sum_inter_add_sum_diff T S f, Finset.inter_comm T S]
  rw [hS_split, hT_split]
  -- Suffices to show ∑ a ∈ S \ T, f a ≤ ∑ a ∈ T \ S, f a
  suffices h : ∑ a ∈ S \ T, f a ≤ ∑ a ∈ T \ S, f a by linarith
  -- |S \ T| = |T \ S|
  have hcard_eq : (S \ T).card = (T \ S).card := by
    have h1 : (S \ T).card + (S ∩ T).card = S.card := by
      rw [← Finset.card_union_of_disjoint (Finset.disjoint_sdiff_inter S T),
        Finset.sdiff_union_inter]
    have h2 : (T \ S).card + (T ∩ S).card = T.card := by
      rw [← Finset.card_union_of_disjoint (Finset.disjoint_sdiff_inter T S),
        Finset.sdiff_union_inter]
    rw [Finset.inter_comm T S] at h2
    omega
  -- Every element of S \ T has val ≥ S.card; every element of T \ S has val < S.card.
  have hab_bound : ∀ a ∈ S \ T, ∀ b ∈ T \ S, f a ≤ f b := by
    intro a ha b hb
    simp only [Finset.mem_sdiff, hTdef, Finset.mem_filter, Finset.mem_univ,
      true_and, not_lt] at ha hb
    apply hf
    -- b.val < S.card ≤ a.val so b ≤ a
    have hbv : b.val < S.card := hb.1
    have hav : S.card ≤ a.val := ha.2
    exact Fin.mk_le_mk.mpr (le_of_lt (lt_of_lt_of_le hbv hav))
  -- Case on whether S \ T is empty.
  by_cases hSTne : (S \ T).Nonempty
  · -- Pick c = max of f on S \ T; ∑_{S\T} f ≤ |S\T| • c ≤ |T\S| • c ≤ ∑_{T\S} f.
    obtain ⟨a₀, ha₀S, ha₀max⟩ := (S \ T).exists_max_image f hSTne
    -- f a ≤ f a₀ for a ∈ S \ T
    have hupper : ∀ a ∈ S \ T, f a ≤ f a₀ := ha₀max
    -- f a₀ ≤ f b for b ∈ T \ S
    have hTSne : (T \ S).Nonempty := by
      rw [← Finset.card_pos, ← hcard_eq, Finset.card_pos]; exact hSTne
    have hlower : ∀ b ∈ T \ S, f a₀ ≤ f b := fun b hb => hab_bound a₀ ha₀S b hb
    calc ∑ a ∈ S \ T, f a
        ≤ (S \ T).card • f a₀ := Finset.sum_le_card_nsmul _ _ _ hupper
      _ = (T \ S).card • f a₀ := by rw [hcard_eq]
      _ ≤ ∑ b ∈ T \ S, f b := Finset.card_nsmul_le_sum _ _ _ hlower
  · rw [Finset.not_nonempty_iff_eq_empty] at hSTne
    rw [hSTne]
    have hTSempty : T \ S = ∅ := by
      rw [← Finset.card_eq_zero, ← hcard_eq, hSTne]; simp
    rw [hTSempty]

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P6.a.Params) : P6.d.Params :=
  { n := p.n
    m := p.m
    d := p.d
    u := p.u
    f := p.f
    c := p.c
    hd_pos := p.hd_pos
    hu_nn := p.hu_nn
    hc_nn := p.hc_nn
    hf_nn := p.hf_nn
    hn := p.hn
    hm := p.hm }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

private def fwd (p : P6.a.Params) (v : P6.a.Vars p) : P6.d.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

-- `v.x i j ≥ 0` for binary `x`.
private lemma xnn {p : P6.a.Params} {v : P6.a.Vars p} (h : P6.a.Feasible p v)
    (i : Fin p.n) (j : Fin p.m) : (0 : ℝ) ≤ (v.x i j : ℝ) := by
  rcases h.hx_bin i j with h0 | h1
  · rw [h0]; simp
  · rw [h1]; norm_num

-- For a hard customer, the assigned warehouse is a large warehouse and is open.
private lemma hard_customer_assigned_large_open
    {p : P6.a.Params} {v : P6.a.Vars p} (h : P6.a.Feasible p v)
    (i : Fin p.n) (hi : i ∈ P6.d.hardCustomers (paramMap p))
    (j : Fin p.m) (hxij : v.x i j = 1) :
    j ∈ P6.d.largeWarehouses (paramMap p) ∧ v.y j = 1 := by
  haveI : NeZero p.n := p.hn
  haveI : NeZero p.m := p.hm
  -- Unfold hard customer membership.
  simp only [P6.d.hardCustomers, Finset.mem_filter, Finset.mem_univ, true_and,
    paramMap] at hi
  -- Capacity bound at j: ∑_{i'} d_{i'} x_{i'j} ≤ u_j * y_j.
  have hcap := h.hcap j
  -- Lower bound: d_i ≤ ∑ i', d i' * x i' j.
  have hdi_le : p.d i ≤ ∑ i' : Fin p.n, p.d i' * (v.x i' j : ℝ) := by
    have hlb : p.d i * (v.x i j : ℝ) ≤ ∑ i' : Fin p.n, p.d i' * (v.x i' j : ℝ) := by
      apply Finset.single_le_sum (f := fun i' : Fin p.n => p.d i' * (v.x i' j : ℝ))
        (s := (univ : Finset (Fin p.n)))
      · intro i' _
        exact mul_nonneg (le_of_lt (p.hd_pos i')) (xnn h i' j)
      · exact Finset.mem_univ i
    have hxij_cast : (v.x i j : ℝ) = 1 := by exact_mod_cast hxij
    rw [hxij_cast] at hlb; simpa using hlb
  have hdi_le_uj_yj : p.d i ≤ p.u j * (v.y j : ℝ) := le_trans hdi_le hcap
  -- Establish y_j = 1.
  have hyj1 : v.y j = 1 := by
    rcases h.hy_bin j with hy0 | hy1
    · exfalso
      rw [hy0] at hdi_le_uj_yj
      simp at hdi_le_uj_yj
      exact absurd hdi_le_uj_yj (not_le.mpr (p.hd_pos i))
    · exact hy1
  have hyj_cast : (v.y j : ℝ) = 1 := by exact_mod_cast hyj1
  rw [hyj_cast, mul_one] at hdi_le_uj_yj
  -- Establish j ∈ T.
  have hjT : j ∈ P6.d.largeWarehouses (paramMap p) := by
    simp only [P6.d.largeWarehouses, Finset.mem_filter, Finset.mem_univ, true_and, paramMap]
    -- Need dMax ≤ u_j.
    -- Key: if j ∉ T, then u_j ≤ uMaxSmall < d_i ≤ u_j. Contradiction.
    -- So j ∈ T. But we need to show dMax ≤ u_j directly.
    -- Instead, use: hi says uMaxSmall < d_i. Combined with d_i ≤ u_j, we have uMaxSmall < u_j.
    -- If j ∉ T, then j ∈ univ \ T, so u_j ≤ uMaxSmall, contradiction.
    -- So j ∈ T means dMax ≤ u_j.
    by_contra hjnot
    push_neg at hjnot
    -- hjnot : ¬ (⨆ i, p.d i) ≤ p.u j
    have hjnotT : j ∈ (univ \ (P6.d.largeWarehouses (paramMap p)) : Finset (Fin p.m)) := by
      simp only [Finset.mem_sdiff, Finset.mem_univ, true_and,
        P6.d.largeWarehouses, Finset.mem_filter, paramMap, not_le]
      exact hjnot
    -- u_j ≤ sup'(univ\T) u.
    have hTc_nonempty : (univ \ P6.d.largeWarehouses (paramMap p) :
        Finset (Fin p.m)).Nonempty := ⟨j, hjnotT⟩
    have huj_le : p.u j ≤ (univ \ P6.d.largeWarehouses (paramMap p)).sup'
        hTc_nonempty p.u := by
      apply Finset.le_sup' (f := p.u) hjnotT
    -- di > uMaxSmall where uMaxSmall matches the sup'.
    have : let uMaxSmall := if h : (univ \ P6.d.largeWarehouses (paramMap p) :
                              Finset (Fin p.m)).Nonempty
                            then (univ \ P6.d.largeWarehouses (paramMap p)).sup' h p.u else 0
           uMaxSmall < p.d i := hi
    simp only [dif_pos hTc_nonempty] at this
    -- p.u j ≤ sup = uMaxSmall < p.d i ≤ p.u j. Contradiction.
    linarith
  exact ⟨hjT, hyj1⟩

private lemma fwd_feas (p : P6.a.Params) (v : P6.a.Vars p)
    (h : P6.a.Feasible p v) :
    P6.d.Feasible (paramMap p) (fwd p v) := by
  haveI : NeZero p.n := p.hn
  haveI : NeZero p.m := p.hm
  refine
    { hassign := ?_
      hcap    := ?_
      hx_bin  := ?_
      hy_bin  := ?_
      hec3    := ?_ }
  · exact h.hassign
  · exact h.hcap
  · exact h.hx_bin
  · exact h.hy_bin
  · -- hec3: T-Cover Bound constraint.
    intro σ hσ k hk_insuff
    classical
    -- Abbreviations (using `let` instead of `set` to avoid σ being re-bound).
    let T := P6.d.largeWarehouses (paramMap p)
    let H := P6.d.hardCustomers (paramMap p)
    -- S : open large warehouses (as subset of Fin T.card)
    let S : Finset (Fin T.card) :=
      (univ : Finset (Fin T.card)).filter (fun a : Fin T.card => v.y (σ a).val = 1)
    have hTdef : T = P6.d.largeWarehouses (paramMap p) := rfl
    have hHdef : H = P6.d.hardCustomers (paramMap p) := rfl
    have hSdef : S = (univ : Finset (Fin T.card)).filter
        (fun a : Fin T.card => v.y (σ a).val = 1) := rfl
    -- Step 1: ∑_{i ∈ H} d_i ≤ ∑_{a ∈ S} u (σ a).
    -- Reorganize: ∑_i d_i x_ij, sum over j ∈ open large warehouses, ≥ hard demand.
    -- For each hard customer i, assigned j* in T is open.
    have assign_hc : ∀ i ∈ H, ∃ j : Fin p.m, v.x i j = 1 ∧
        j ∈ T ∧ v.y j = 1 := by
      intro i hi
      -- ∃ j with x i j = 1 from hassign and hx_bin.
      have hsum := h.hassign i
      have hex : ∃ j : Fin p.m, v.x i j = 1 := by
        by_contra hcon
        push_neg at hcon
        have h0 : ∀ j : Fin p.m, v.x i j = 0 := fun j =>
          (h.hx_bin i j).resolve_right (hcon j)
        simp [h0] at hsum
      obtain ⟨j, hxij⟩ := hex
      have ⟨hjT, hyj1⟩ := hard_customer_assigned_large_open h i hi j hxij
      exact ⟨j, hxij, hjT, hyj1⟩
    -- Demand bound: for each j in T with y_j = 1, ∑_{i∈H} d_i * x_{ij} ≤ u_j.
    -- Sum over open T gives hard demand ≤ ∑_{a∈S} u(σ a).
    -- First, rewrite hard demand as sum over j ∈ open-T of per-j hard demand.
    -- Define h_dem_j := ∑_{i∈H} d_i * x_{ij}.
    have hard_demand_split : ∑ i ∈ H, p.d i =
        ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
          ∑ i ∈ H, p.d i * (v.x i j : ℝ) := by
      -- For each i, ∑_j d_i * x_{ij} = d_i * ∑_j x_{ij} = d_i.
      -- We restrict the j-sum to open T. Fill non-open with 0.
      -- Strategy: use that x_{ij} = 0 when j not in open T (for i hard).
      rw [Finset.sum_comm]
      apply Finset.sum_congr rfl
      intro i hi
      obtain ⟨j₀, hxij₀, hj₀T, hyj₀1⟩ := assign_hc i hi
      -- The only j that contributes to the sum is j₀.
      -- For any other j in open T, x i j = 0.
      have x_eq_zero : ∀ j : Fin (paramMap p).m, j ≠ j₀ → v.x i j = 0 := by
        intro j hjne
        rcases h.hx_bin i j with h0 | h1
        · exact h0
        · exfalso
          have hsum := h.hassign i
          have hge : (∑ j' : Fin (paramMap p).m, v.x i j') ≥ v.x i j + v.x i j₀ := by
            calc (∑ j' : Fin (paramMap p).m, v.x i j')
                ≥ ∑ j' ∈ ({j, j₀} : Finset (Fin (paramMap p).m)), v.x i j' :=
                  Finset.sum_le_sum_of_subset_of_nonneg (Finset.subset_univ _)
                    (fun j' _ _ => by rcases h.hx_bin i j' with h0' | h1' <;> omega)
              _ = v.x i j + v.x i j₀ := Finset.sum_pair hjne
          rw [h1, hxij₀] at hge
          -- hge: ∑ j', v.x i j' ≥ 2; hsum: ∑ j, v.x i j = 1
          have : (2 : ℤ) ≤ 1 := hge.trans_eq hsum
          omega
      -- Sum of d i * x i j over filter = d i * 1 = d i.
      rw [show ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
            p.d i * (v.x i j : ℝ) =
          p.d i * ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
            (v.x i j : ℝ) from (Finset.mul_sum _ _ _).symm]
      -- Show ∑_{j in open T} x_{ij} = 1.
      have hj₀_cast : (j₀ : Fin (paramMap p).m) = j₀ := rfl
      have hj₀_in_filter : (j₀ : Fin (paramMap p).m) ∈
          T.filter (fun j : Fin (paramMap p).m => v.y j = 1) :=
        Finset.mem_filter.mpr ⟨hj₀T, hyj₀1⟩
      have hxsum : ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
          (v.x i j : ℝ) = 1 := by
        have h_eq : ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
            (v.x i j : ℝ) = (v.x i j₀ : ℝ) :=
          Finset.sum_eq_single (j₀ : Fin (paramMap p).m)
            (fun j _ hjne => by exact_mod_cast x_eq_zero j hjne)
            (fun hnot => absurd hj₀_in_filter hnot)
        rw [h_eq]; exact_mod_cast hxij₀
      rw [hxsum, mul_one]
    -- Per-j bound ∑_{i∈H} d_i * x_ij ≤ u_j * y_j = u_j for j open.
    have per_j_bound : ∀ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1),
        ∑ i ∈ H, p.d i * (v.x i j : ℝ) ≤ p.u j := by
      intro j hj
      rw [Finset.mem_filter] at hj
      have hyj1 : v.y j = 1 := hj.2
      have hcap := h.hcap j
      have hyj_cast : (v.y j : ℝ) = 1 := by exact_mod_cast hyj1
      rw [hyj_cast, mul_one] at hcap
      -- ∑_{i∈H} d i * x ≤ ∑_{i : Fin p.n} d i * x
      apply le_trans _ hcap
      apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.subset_univ _)
      intro i _ _
      exact mul_nonneg (le_of_lt (p.hd_pos i)) (xnn h i j)
    have hard_le_openT_cap : ∑ i ∈ H, p.d i ≤
        ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1), p.u j := by
      rw [hard_demand_split]
      exact Finset.sum_le_sum per_j_bound
    -- Express RHS via σ bijection: ∑_{j ∈ open T} u_j = ∑_{a ∈ S} u(σ a).
    have sum_via_sigma :
        ∑ j ∈ T.filter (fun j : Fin (paramMap p).m => v.y j = 1), p.u j =
        ∑ a ∈ S, p.u (σ a).val := by
      -- Bijection between S and T.filter (y = 1). S = {a : y(σ a) = 1}, σ : S ≃ that.
      -- Use Finset.sum_bij via e : S → T.filter (...).
      symm
      refine Finset.sum_nbij
        (fun (a : Fin T.card) => ((σ a).val : Fin (paramMap p).m))
        ?_ ?_ ?_ ?_
      · intro a ha
        simp only [hSdef, Finset.mem_filter, Finset.mem_univ, true_and] at ha
        rw [Finset.mem_filter]
        exact ⟨(σ a).2, ha⟩
      · intro a ha b hb hab
        simp only at hab
        have : σ a = σ b := Subtype.ext hab
        exact σ.injective this
      · intro j hj
        simp only [Finset.coe_filter, Set.mem_setOf_eq] at hj
        obtain ⟨hjT, hyj⟩ := hj
        refine ⟨σ.symm ⟨j, hjT⟩, ?_, ?_⟩
        · simp only [hSdef, Finset.coe_filter, Set.mem_setOf_eq,
            Finset.mem_univ, true_and, Equiv.apply_symm_apply]
          exact hyj
        · simp [Equiv.apply_symm_apply]
      · intros; rfl
    rw [sum_via_sigma] at hard_le_openT_cap
    -- Now by helper: ∑_{a ∈ S} u(σ a) ≤ ∑_{a.val < S.card} u(σ a).
    have f_antitone : ∀ a b : Fin T.card, a ≤ b → p.u (σ b).val ≤ p.u (σ a).val := by
      intro a b hab
      have := hσ a b hab
      exact this
    have sum_S_le_top :=
      sum_le_sum_top_of_antitone (fun a : Fin T.card => p.u (σ a).val) f_antitone S
    -- Combine: ∑_{i∈H} d_i ≤ ∑_{a ∈ S} ... ≤ ∑_{a.val < S.card} ...
    have hhard_le_top : ∑ i ∈ H, p.d i ≤
        ∑ a ∈ (univ : Finset (Fin T.card)).filter (fun i : Fin T.card => i.val < S.card),
          p.u (σ a).val := by
      exact le_trans hard_le_openT_cap sum_S_le_top
    -- ∑_j y_j ≥ S.card.
    have Scard_le_y : (S.card : ℤ) ≤ ∑ j : Fin p.m, v.y j := by
      -- Map S ↪ Fin p.m via σ, image is subset of open warehouses.
      have hinj : Function.Injective (fun a : S => ((σ a.val).val : Fin p.m)) := by
        intro a b hab
        simp only at hab
        have : σ a.val = σ b.val := Subtype.ext hab
        have : a.val = b.val := σ.injective this
        exact Subtype.ext this
      -- ∑_j y_j = ∑_{j open} 1 + ∑_{j closed} 0 ≥ # open j.
      -- All σ a for a ∈ S are open (y = 1).
      have hybin_nn : ∀ j : Fin p.m, (0 : ℤ) ≤ v.y j := by
        intro j; rcases h.hy_bin j with h0 | h1 <;> omega
      -- Injective image of S in Fin p.m has card = S.card.
      set img : Finset (Fin p.m) := S.image (fun a : Fin T.card => ((σ a).val : Fin p.m))
      have himg_card : img.card = S.card := by
        apply Finset.card_image_of_injective
        intro a b hab
        simp only at hab
        have : σ a = σ b := Subtype.ext hab
        exact σ.injective this
      -- All j ∈ img have y_j = 1.
      have himg_yj : ∀ j ∈ img, v.y j = 1 := by
        intro j hj
        rw [Finset.mem_image] at hj
        obtain ⟨a, haS, haeq⟩ := hj
        rw [hSdef, Finset.mem_filter] at haS
        rw [← haeq]; exact haS.2
      calc (S.card : ℤ) = (img.card : ℤ) := by rw [himg_card]
        _ = ∑ j ∈ img, (1 : ℤ) := by simp
        _ = ∑ j ∈ img, v.y j := by
              apply Finset.sum_congr rfl
              intro j hj; exact (himg_yj j hj).symm
        _ ≤ ∑ j : Fin p.m, v.y j := by
              apply Finset.sum_le_sum_of_subset_of_nonneg (Finset.subset_univ _)
              intro j _ _; exact hybin_nn j
    -- Now: if S.card < k then sum over top S.card < sum over top k.
    -- Combined with hard demand inequality + hk_insuff, get contradiction.
    -- So S.card ≥ k. Hence k ≤ S.card ≤ ∑ y_j.
    by_contra hcon
    push_neg at hcon
    -- hcon : ∑ y_j < (k : ℤ).
    have hScard_lt : (S.card : ℤ) < k := lt_of_le_of_lt Scard_le_y hcon
    have hScard_lt' : S.card < k := by exact_mod_cast hScard_lt
    -- Top-S.card sum ≤ Top-k sum (monotone on filters).
    have hmono : ∑ a ∈ (univ : Finset (Fin T.card)).filter
          (fun i : Fin T.card => i.val < S.card), p.u (σ a).val
        ≤ ∑ a ∈ (univ : Finset (Fin T.card)).filter
          (fun i : Fin T.card => i.val < k), p.u (σ a).val := by
      apply Finset.sum_le_sum_of_subset_of_nonneg
      · intro a ha
        simp only [Finset.mem_filter, Finset.mem_univ, true_and] at ha ⊢
        omega
      · intro a _ _
        exact p.hu_nn _
    have hchain : ∑ i ∈ H, p.d i < ∑ i ∈ H, p.d i := by
      calc ∑ i ∈ H, p.d i
          ≤ ∑ a ∈ (univ : Finset (Fin T.card)).filter
              (fun i : Fin T.card => i.val < S.card), p.u (σ a).val := hhard_le_top
        _ ≤ ∑ a ∈ (univ : Finset (Fin T.card)).filter
              (fun i : Fin T.card => i.val < k), p.u (σ a).val := hmono
        _ < ∑ i ∈ H, p.d i := by exact hk_insuff
    exact lt_irrefl _ hchain

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

private def bwd (p : P6.a.Params) (v : P6.d.Vars (paramMap p)) : P6.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P6.a.Params) (v : P6.d.Vars (paramMap p))
    (h : P6.d.Feasible (paramMap p) v) :
    P6.a.Feasible p (bwd p v) := by
  simp only [bwd, paramMap] at *
  exact
    { hassign := h.hassign
      hcap    := h.hcap
      hx_bin  := h.hx_bin
      hy_bin  := h.hy_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aDReformulation : MILPReformulation P6.a.formulation P6.d.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  bwd_fwd     := fun _ _ _ => rfl
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P6
