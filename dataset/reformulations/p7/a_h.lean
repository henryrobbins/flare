import Common
import problems.p7.formulations.a.Formulation
import problems.p7.formulations.h.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Fintype.Prod
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P7

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P7.a.Params) : P7.h.Params :=
  { N  := p.N
    hN := p.hN }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

-- fwd is the identity on variables; h adds the V2 EC1 cut, which we must prove.
private def fwd (p : P7.a.Params) (v : P7.a.Vars p) : P7.h.Vars (paramMap p) :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

-- strips_covering is defined identically in the two namespaces; the Finset
-- has the same underlying filter on `Fin p.N × Fin p.N`.
private lemma strips_covering_eq (N : ℕ) (j : Fin N) :
    P7.a.strips_covering N j = P7.h.strips_covering N j := rfl

section ForwardHelpers

variable {p : P7.a.Params} {v : P7.a.Vars p} (h : P7.a.Feasible p v)
include h

-- Each t value is nonneg.
private lemma fwd_t_nn (i : Fin p.N) (ab : Fin p.N × Fin p.N) :
    0 ≤ v.t i ab.1 ab.2 := by
  rcases h.ht_bin i ab with h0 | h1 <;> omega

-- EC1 (V2) holds on any a-feasible point.
private lemma fwd_ec1 (i : Fin p.N) (j : Fin p.N) (hi : 0 < i.val) :
    v.h ⟨i.val - 1, by omega⟩ j - v.h i j ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 := by
  -- i - 1 as a Fin p.N
  have hi_lt : i.val - 1 < p.N := by omega
  let i' : Fin p.N := ⟨i.val - 1, hi_lt⟩
  -- Step 1: pointwise, s_i^{ab} ≥ x_i^{ab} - x_{i-1}^{ab}  (from flow + t ≥ 0)
  have hs_ge : ∀ ab ∈ P7.a.strips_covering p.N j,
      v.x i ab.1 ab.2 - v.x i' ab.1 ab.2 ≤
        v.s i ab.1 ab.2 := by
    intro ab _
    have hfl := h.hflow i ab hi
    have ht_nn := fwd_t_nn h i' ab
    -- hflow: x i - x (i-1) - s i + t (i-1) = 0, so s i = x i - x (i-1) + t (i-1)
    show v.x i ab.1 ab.2 - v.x i' ab.1 ab.2 ≤
        v.s i ab.1 ab.2
    -- hfl uses ⟨i.val - 1, _⟩ which is defeq to i'
    change v.x i ab.1 ab.2 - v.x ⟨i.val - 1, _⟩ ab.1 ab.2 -
        v.s i ab.1 ab.2 + v.t ⟨i.val - 1, _⟩ ab.1 ab.2 = 0 at hfl
    linarith
  -- Step 2: sum the pointwise bound
  have hsum_ge :
      ∑ ab ∈ P7.a.strips_covering p.N j,
        (v.x i ab.1 ab.2 - v.x i' ab.1 ab.2) ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2 :=
    Finset.sum_le_sum hs_ge
  -- Step 3: coverage at rows i and i-1
  have hcov_i := h.hcov i j
  have hcov_prev := h.hcov i' j
  -- Step 4: split the sum of differences
  have hsplit :
      ∑ ab ∈ P7.a.strips_covering p.N j,
        (v.x i ab.1 ab.2 - v.x i' ab.1 ab.2) =
      (∑ ab ∈ P7.a.strips_covering p.N j, v.x i ab.1 ab.2) -
        ∑ ab ∈ P7.a.strips_covering p.N j, v.x i' ab.1 ab.2 :=
    Finset.sum_sub_distrib _ _
  show v.h ⟨i.val - 1, _⟩ j - v.h i j ≤
      ∑ ab ∈ P7.a.strips_covering p.N j, v.s i ab.1 ab.2
  change v.h i' j - v.h i j ≤ _
  linarith

end ForwardHelpers

private lemma fwd_feas (p : P7.a.Params) (v : P7.a.Vars p)
    (h : P7.a.Feasible p v) :
    P7.h.Feasible (paramMap p) (fwd p v) := by
  exact
    { hrow    := h.hrow
      hcol    := h.hcol
      hcov    := h.hcov
      htop    := h.htop
      hflow   := h.hflow
      hbot    := h.hbot
      hh_bin  := h.hh_bin
      hx_bin  := h.hx_bin
      hs_bin  := h.hs_bin
      ht_bin  := h.ht_bin
      hvacCol := fwd_ec1 h }

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

-- bwd drops the EC1 cut.
private def bwd (p : P7.a.Params) (v : P7.h.Vars (paramMap p)) : P7.a.Vars p :=
  { h := v.h
    x := v.x
    s := v.s
    t := v.t }

private lemma bwd_feas (p : P7.a.Params) (v : P7.h.Vars (paramMap p))
    (h : P7.h.Feasible (paramMap p) v) :
    P7.a.Feasible p (bwd p v) := by
  exact
    { hrow   := h.hrow
      hcol   := h.hcol
      hcov   := h.hcov
      htop   := h.htop
      hflow  := h.hflow
      hbot   := h.hbot
      hh_bin := h.hh_bin
      hx_bin := h.hx_bin
      hs_bin := h.hs_bin
      ht_bin := h.ht_bin }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aHReformulation : MILPReformulation P7.a.formulation P7.h.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P7
