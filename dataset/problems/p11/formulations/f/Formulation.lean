import Common
import Mathlib.Algebra.BigOperators.Group.Finset.Basic
import Mathlib.Data.Fintype.Basic
import Mathlib.Data.Real.Basic
import Mathlib.Data.Int.Basic

open BigOperators Finset

namespace P11.f

structure Params where
  -- Dimensions
  nT : ℕ -- number of time periods
  nG : ℕ -- number of thermal generators
  nW : ℕ -- number of renewable (wind) generators
  nS : Fin nG → ℕ -- number of startup categories per generator
  nL : Fin nG → ℕ -- number of piecewise breakpoints per generator
  -- Startup data
  ell : ∀ g : Fin nG, Fin (nS g) → ℕ -- startup lag for each category
  C_su : ∀ g : Fin nG, Fin (nS g) → ℝ -- startup cost for each category
  -- Piecewise production data
  P : ∀ g : Fin nG, Fin (nL g) → ℝ -- piecewise output breakpoints
  C : ∀ g : Fin nG, Fin (nL g) → ℝ -- piecewise variable cost at breakpoints
  C_fixed : Fin nG → ℝ -- fixed on-cost per generator per period
  -- System parameters
  L : Fin nT → ℝ -- demand at each time period
  R : Fin nT → ℝ -- spinning reserve requirement at each time period
  -- Thermal generator limits
  P_min : Fin nG → ℝ -- minimum thermal output
  P_max : Fin nG → ℝ -- maximum thermal output
  -- Renewable generator bounds
  P_wind_min : Fin nW → Fin nT → ℝ -- minimum renewable output
  P_wind_max : Fin nW → Fin nT → ℝ -- maximum renewable output
  -- Ramp and startup/shutdown ramp limits
  RU : Fin nG → ℝ -- ramp-up limit
  RD : Fin nG → ℝ -- ramp-down limit
  SU : Fin nG → ℝ -- startup ramp limit
  SD : Fin nG → ℝ -- shutdown ramp limit
  -- Minimum up/down times and must-run
  U : Fin nG → ℕ -- minimum up time
  D : Fin nG → ℕ -- minimum down time
  MR : Fin nG → ℝ -- must-run level
  -- Implicit Assumptions
  hT_pos : NeZero nT
  hG_pos : NeZero nG
  hW_pos : NeZero nW
  hnS_pos : ∀ g : Fin nG, NeZero (nS g)
  hnL_pos : ∀ g : Fin nG, NeZero (nL g)
  hCsu_nn : ∀ g : Fin nG, ∀ s : Fin (nS g), 0 ≤ C_su g s
  hP_nn : ∀ g : Fin nG, ∀ l : Fin (nL g), 0 ≤ P g l
  hC_nn : ∀ g : Fin nG, ∀ l : Fin (nL g), 0 ≤ C g l
  hCfixed_nn : ∀ g : Fin nG, 0 ≤ C_fixed g
  hL_nn : ∀ t : Fin nT, 0 ≤ L t
  hR_nn : ∀ t : Fin nT, 0 ≤ R t
  hPmin_nn : ∀ g : Fin nG, 0 ≤ P_min g
  hPmax_nn : ∀ g : Fin nG, 0 ≤ P_max g
  hPmax_ge : ∀ g : Fin nG, P_min g ≤ P_max g
  hPwmin_nn : ∀ w : Fin nW, ∀ t : Fin nT, 0 ≤ P_wind_min w t
  hPwmax_nn : ∀ w : Fin nW, ∀ t : Fin nT, 0 ≤ P_wind_max w t
  hPw_le : ∀ w : Fin nW, ∀ t : Fin nT, P_wind_min w t ≤ P_wind_max w t
  hRU_nn : ∀ g : Fin nG, 0 ≤ RU g
  hRD_nn : ∀ g : Fin nG, 0 ≤ RD g
  hSU_nn : ∀ g : Fin nG, 0 ≤ SU g
  hSD_nn : ∀ g : Fin nG, 0 ≤ SD g
  hU_pos : ∀ g : Fin nG, 1 ≤ U g
  hD_pos : ∀ g : Fin nG, 1 ≤ D g
  hMR_nn : ∀ g : Fin nG, 0 ≤ MR g

structure Vars where
  u : ℕ → ℕ → ℤ -- on status of generator g at time t
  v : ℕ → ℕ → ℤ -- startup indicator of generator g at time t
  w : ℕ → ℕ → ℤ -- shutdown indicator of generator g at time t
  d_su : ℕ → ℕ → ℕ → ℤ -- startup category selection (g, s, t)
  lam : ℕ → ℕ → ℕ → ℝ -- piecewise weight (g, l, t)
  p : ℕ → ℕ → ℝ -- thermal output above P_min for generator g at time t
  r : ℕ → ℕ → ℝ -- spinning reserve of generator g at time t
  c_var : ℕ → ℕ → ℝ -- variable production cost above fixed cost
  p_wind : ℕ → ℕ → ℝ -- renewable output for wind generator w at time t
  P_bar : ℕ → ℕ → ℝ -- maximum reachable output of generator g at time t

structure Feasible (p : Params) (v : Vars) : Prop where
  -- Demand balance: total thermal output equals demand at each period
  hdemand : ∀ t : Fin p.nT,
    ∑ g : Fin p.nG, (v.p g.val t.val + p.P_min g * (v.u g.val t.val : ℝ)) = p.L t
  -- Spinning reserve: total reserve meets or exceeds requirement
  hreserve : ∀ t : Fin p.nT,
    p.R t ≤ ∑ g : Fin p.nG, v.r g.val t.val
  -- Commitment transition for t ≥ 1
  htransition : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 < t.val →
    (v.u g.val t.val : ℤ) - v.u g.val (t.val - 1) = v.v g.val t.val - v.w g.val t.val
  -- Minimum up time: sum of startups in window ≤ on-status
  hmin_up : ∀ g : Fin p.nG, ∀ t : Fin p.nT, p.U g - 1 ≤ t.val →
    ∑ τ ∈ (univ : Finset (Fin p.nT)).filter
      (fun τ => t.val - (p.U g - 1) ≤ τ.val ∧ τ.val ≤ t.val),
      v.v g.val τ.val ≤ (v.u g.val t.val : ℤ)
  -- Minimum down time: sum of shutdowns in window ≤ 1 - on-status
  hmin_dn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, p.D g - 1 ≤ t.val →
    ∑ τ ∈ (univ : Finset (Fin p.nT)).filter
      (fun τ => t.val - (p.D g - 1) ≤ τ.val ∧ τ.val ≤ t.val),
      v.w g.val τ.val ≤ 1 - (v.u g.val t.val : ℤ)
  -- Startup decomposition: startup indicator equals sum of category selections
  hv_decomp : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.v g.val t.val = ∑ s : Fin (p.nS g), v.d_su g.val s.val t.val
  -- Startup category timing: category s can be selected only after required lag
  hlag : ∀ g : Fin p.nG, ∀ s : Fin (p.nS g), ∀ t : Fin p.nT,
    ∀ hs : s.val + 1 < p.nS g, p.ell g ⟨s.val + 1, hs⟩ - 1 ≤ t.val →
    v.d_su g.val s.val t.val ≤
      ∑ i ∈ (Finset.range (p.ell g ⟨s.val + 1, hs⟩ - p.ell g s)).filter
        (fun i => p.ell g s + i ≤ t.val),
        v.w g.val (t.val - (p.ell g s + i))
  -- Must-run: generators with MR > 0 must remain on
  hmust_run : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    p.MR g ≤ (v.u g.val t.val : ℝ)
  -- Startup derating: output + reserve limited by startup ramp during startup
  hcap_su : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.p g.val t.val + v.r g.val t.val ≤
      (p.P_max g - p.P_min g) * (v.u g.val t.val : ℝ) -
        max (p.P_max g - p.SU g) 0 * (v.v g.val t.val : ℝ)
  -- Shutdown derating: output + reserve limited by shutdown ramp the period before shutdown
  hcap_sd : ∀ g : Fin p.nG, ∀ t : Fin p.nT, t.val + 1 < p.nT →
    v.p g.val t.val + v.r g.val t.val ≤
      (p.P_max g - p.P_min g) * (v.u g.val t.val : ℝ) -
        max (p.P_max g - p.SD g) 0 * (v.w g.val (t.val + 1) : ℝ)
  -- Ramp-up limit for t ≥ 1
  hramp_up : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 < t.val →
    v.p g.val t.val + v.r g.val t.val - v.p g.val (t.val - 1) ≤ p.RU g
  -- Ramp-down limit for t ≥ 1
  hramp_dn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 < t.val →
    v.p g.val (t.val - 1) - v.p g.val t.val ≤ p.RD g
  -- Piecewise production: output equals convex combination of breakpoints above min
  hp_eq : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.p g.val t.val = ∑ l : Fin (p.nL g),
      (p.P g l - p.P g ⟨0, (p.hnL_pos g).pos⟩) * v.lam g.val l.val t.val
  -- Piecewise cost: variable cost equals convex combination of cost breakpoints above fixed cost
  hc_eq : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    v.c_var g.val t.val = ∑ l : Fin (p.nL g),
      (p.C g l - p.C_fixed g) * v.lam g.val l.val t.val
  -- Piecewise weights sum to on-status
  hlam_sum : ∀ g : Fin p.nG, ∀ t : Fin p.nT,
    ∑ l : Fin (p.nL g), v.lam g.val l.val t.val = (v.u g.val t.val : ℝ)
  -- Binary variables
  hu_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.u g.val t.val = 0 ∨ v.u g.val t.val = 1
  hv_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.v g.val t.val = 0 ∨ v.v g.val t.val = 1
  hw_bin : ∀ g : Fin p.nG, ∀ t : Fin p.nT, v.w g.val t.val = 0 ∨ v.w g.val t.val = 1
  hd_bin : ∀ g : Fin p.nG, ∀ s : Fin (p.nS g), ∀ t : Fin p.nT,
    v.d_su g.val s.val t.val = 0 ∨ v.d_su g.val s.val t.val = 1
  -- Non-negativity of continuous variables
  hlam_nn : ∀ g : Fin p.nG, ∀ l : Fin (p.nL g), ∀ t : Fin p.nT, 0 ≤ v.lam g.val l.val t.val
  hlam_le : ∀ g : Fin p.nG, ∀ l : Fin (p.nL g), ∀ t : Fin p.nT, v.lam g.val l.val t.val ≤ 1
  hp_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.p g.val t.val
  hr_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.r g.val t.val
  hcvar_nn : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 ≤ v.c_var g.val t.val
  -- Renewable output bounds
  hpwind_lo : ∀ w : Fin p.nW, ∀ t : Fin p.nT, p.P_wind_min w t ≤ v.p_wind w.val t.val
  hpwind_hi : ∀ w : Fin p.nW, ∀ t : Fin p.nT, v.p_wind w.val t.val ≤ p.P_wind_max w t
  -- EC3a: P_bar bounded by previous period output plus ramp-up, relaxed when generator was offline
  hec3a : ∀ g : Fin p.nG, ∀ t : Fin p.nT, 0 < t.val →
    v.P_bar g.val t.val ≤
      p.P_min g * (v.u g.val t.val : ℝ) + v.p g.val (t.val - 1) + p.RU g +
        (p.P_max g - p.P_min g) * (1 - (v.u g.val (t.val - 1) : ℝ))

-- Minimize total production cost (fixed on-cost + variable cost) and startup costs
def obj (p : Params) (v : Vars) : ℝ :=
  (∑ g : Fin p.nG, ∑ t : Fin p.nT,
    (v.c_var g.val t.val + p.C_fixed g * (v.u g.val t.val : ℝ))) +
  ∑ g : Fin p.nG, ∑ s : Fin (p.nS g), ∑ t : Fin p.nT,
    p.C_su g s * (v.d_su g.val s.val t.val : ℝ)

def formulation : MILPFormulation where
  Params   := Params
  Vars     := Vars
  feasible := Feasible
  obj      := obj

end P11.f
