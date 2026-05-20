import Common
import problems.p9.formulations.a.Formulation
import problems.p9.formulations.b.Formulation
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic
import Mathlib.Tactic

open BigOperators Finset

namespace P9

-- ============================================================================
-- § Parameter Mapping
-- ============================================================================

private def paramMap (p : P9.a.Params) : P9.b.Params :=
  { n      := p.n
    m      := p.m
    K      := p.K
    tail   := p.tail
    head   := p.head
    c      := p.c
    f      := p.f
    u      := p.u
    O      := p.O
    D      := p.D
    d      := p.d
    hn     := p.hn
    hm     := p.hm
    hK     := p.hK
    hc_nn  := p.hc_nn
    hf_nn  := p.hf_nn
    hd_pos := p.hd_pos
    hu_nn  := p.hu_nn }

-- ============================================================================
-- § Forward Mapping and Feasibility
-- ============================================================================

section ForwardHelpers

variable {p : P9.a.Params} {v : P9.a.Vars p} (h : P9.a.Feasible p v)
include h

/-- The incoming-arcs set δ⁻(D_k) is nonempty: otherwise the inflow sum is 0 but
    it must equal the positive demand d_k. -/
private lemma inArcs_nonempty (k : Fin p.K) :
    (univ.filter (fun e : Fin p.m => p.head e = p.D k)).Nonempty := by
  haveI := p.hm
  by_contra hempty
  rw [not_nonempty_iff_eq_empty] at hempty
  have hzero :
      (univ.filter (fun e : Fin p.m => p.head e = p.D k)).sum (fun e => v.x e k) = 0 := by
    simp [hempty]
  linarith [h.hin k, p.hd_pos k]

/-- Per-commodity capacity: x_{e,k} ≤ u_e * y_e follows from the aggregate bound
    and nonnegativity of all x_{e,k'}. -/
private lemma per_commodity_cap (e : Fin p.m) (k : Fin p.K) :
    v.x e k ≤ p.u e * (v.y e : ℝ) := by
  haveI := p.hK
  have hsum : v.x e k ≤ ∑ k' : Fin p.K, v.x e k' :=
    Finset.single_le_sum
      (f := fun k' : Fin p.K => v.x e k')
      (s := univ)
      (hf := fun k' _ => h.hx_nn e k')
      (mem_univ k)
  exact le_trans hsum (h.hcap e)

end ForwardHelpers

/--
**P9.a → P9.b**: identity on variables. We must additionally verify the
destination in-cut bound (EC1).
-/
private def fwd (p : P9.a.Params) (v : P9.a.Vars p) : P9.b.Vars (paramMap p) :=
  { x := v.x
    y := v.y }

private lemma fwd_feas (p : P9.a.Params) (v : P9.a.Vars p)
    (h : P9.a.Feasible p v) :
    P9.b.Feasible (paramMap p) (fwd p v) := by
  haveI := p.hm
  haveI := p.hK
  refine
    { hout  := h.hout
      hin   := h.hin
      hbal  := h.hbal
      hcap  := h.hcap
      hx_nn := h.hx_nn
      hy_bin := h.hy_bin
      hsink := h.hsink
      hec1  := ?_ }
  -- EC1 proof, following the EC1.lean reference.
  intro k
  -- The incoming-arcs set.
  set S : Finset (Fin p.m) :=
    univ.filter (fun e : Fin p.m => p.head e = p.D k) with hS
  have hS_ne : S.Nonempty := inArcs_nonempty h k
  -- The goal involves an if-guarded uMax; since S is nonempty, we simplify.
  -- We first produce the uMax value abstractly via sup'.
  set uM : ℝ := S.sup' hS_ne p.u with huM_def
  have huMax_nn : 0 ≤ uM := by
    obtain ⟨e₀, he₀⟩ := hS_ne
    exact le_trans (p.hu_nn e₀) (le_sup' p.u he₀)
  -- Main inequality on S.
  have hmain :
      p.d k + uM ≤ S.sum (fun e => (p.u e + uM) * (v.y e : ℝ)) := by
    -- Decompose the sum.
    have hdecomp :
        S.sum (fun e => (p.u e + uM) * (v.y e : ℝ)) =
        S.sum (fun e => p.u e * (v.y e : ℝ)) +
        uM * S.sum (fun e => (v.y e : ℝ)) := by
      simp_rw [add_mul]
      rw [sum_add_distrib, ← mul_sum]
    rw [hdecomp]
    -- Step 1: d k ≤ ∑ u_e y_e on S.
    have hcap_bound : p.d k ≤ S.sum (fun e => p.u e * (v.y e : ℝ)) :=
      calc p.d k
          = S.sum (fun e => v.x e k) := by
            have := h.hin k; simpa [hS] using this.symm
        _ ≤ S.sum (fun e => p.u e * (v.y e : ℝ)) :=
            sum_le_sum fun e _ => per_commodity_cap h e k
    -- Step 2: ∑ y_e ≥ 1 on S.
    have hactive : (1 : ℝ) ≤ S.sum (fun e => (v.y e : ℝ)) := by
      by_contra hlt
      push_neg at hlt
      have hall_zero : ∀ e ∈ S, v.y e = 0 := by
        intro e he
        rcases h.hy_bin e with h0 | h1
        · exact h0
        · exfalso
          have hy_nn : ∀ e' ∈ S, (0 : ℤ) ≤ v.y e' := fun e' _ => by
            rcases h.hy_bin e' with h0' | h1'
            · rw [h0']
            · rw [h1']; omega
          have hge : (1 : ℤ) ≤ S.sum (fun e' => v.y e') :=
            calc (1 : ℤ) = v.y e := h1.symm
              _ ≤ S.sum (fun e' => v.y e') :=
                  single_le_sum (f := fun e' : Fin p.m => v.y e') hy_nn he
          have hge_r : (1 : ℝ) ≤ S.sum (fun e' => (v.y e' : ℝ)) := by
            have hcast : ((1 : ℤ) : ℝ) ≤ ((S.sum (fun e' => v.y e') : ℤ) : ℝ) :=
              by exact_mod_cast hge
            push_cast at hcast
            exact hcast
          linarith
      have hflow_zero : ∀ e ∈ S, v.x e k ≤ 0 := fun e he => by
        have hcap := per_commodity_cap h e k
        have hye0 : (v.y e : ℝ) = 0 := by exact_mod_cast hall_zero e he
        rw [hye0, mul_zero] at hcap; exact hcap
      have hsum_le : S.sum (fun e => v.x e k) ≤ 0 :=
        sum_nonpos fun e he => hflow_zero e he
      have hin_k : S.sum (fun e => v.x e k) = p.d k := by
        simpa [hS] using h.hin k
      linarith [p.hd_pos k]
    -- Step 3: uM ≤ uM * ∑ y_e.
    have humax_bound : uM ≤ uM * S.sum (fun e => (v.y e : ℝ)) :=
      le_mul_of_one_le_right huMax_nn hactive
    linarith
  -- Transfer hmain to the actual goal. `incArcs` is an `abbrev` that unfolds
  -- to `S`; `uMax` unfolds to a `dite` whose `then` branch is `S.sup' _ p.u`
  -- when `S` is nonempty. `(paramMap p).{head,u,D,d}` reduce to `p.{head,u,D,d}`.
  show S.sum (fun e => (p.u e +
      (if h' : S.Nonempty then S.sup' h' p.u else (0 : ℝ))) *
      (v.y e : ℝ)) ≥
    p.d k +
      (if h' : S.Nonempty then S.sup' h' p.u else (0 : ℝ))
  rw [dif_pos hS_ne]
  exact hmain

-- ============================================================================
-- § Backward Mapping and Feasibility
-- ============================================================================

/--
**P9.b → P9.a**: identity on variables. All the constraints except `hec1`
transfer directly; `hec1` is simply dropped.
-/
private def bwd (p : P9.a.Params) (v : P9.b.Vars (paramMap p)) : P9.a.Vars p :=
  { x := v.x
    y := v.y }

private lemma bwd_feas (p : P9.a.Params) (v : P9.b.Vars (paramMap p))
    (h : P9.b.Feasible (paramMap p) v) :
    P9.a.Feasible p (bwd p v) := by
  exact
    { hout   := h.hout
      hin    := h.hin
      hbal   := h.hbal
      hcap   := h.hcap
      hx_nn  := h.hx_nn
      hy_bin := h.hy_bin
      hsink  := h.hsink }

-- ============================================================================
-- § Reformulation Structure
-- ============================================================================

def aBReformulation : MILPReformulation P9.a.formulation P9.b.formulation where
  paramMap    := paramMap
  fwd         := fwd
  bwd         := bwd
  fwd_feas    := fwd_feas
  bwd_feas    := bwd_feas
  objMap      := id
  objMap_mono := strictMono_id
  fwd_obj _ _ _ := rfl
  bwd_obj _ _ _ := rfl

end P9
