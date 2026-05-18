# Reformulation Definition

Reformulation has an intuitive operational meaning: $\mathcal{M}'$ is
a reformulation of $\mathcal{M}$ if one can map an instance
$\mathcal{M}(p)$ to an instance $\mathcal{M}'(p')$, solve
$\mathcal{M}'(p')$, and efficiently recover an optimal solution to
$\mathcal{M}(p)$. Importantly, this is a *formulation-level* claim
that holds across *all* problem instances $p \in \mathcal{P}$.

FormulationBench adopts a *constructive* definition of reformulation
that is amenable to formalization and tractable for automated
formal-proof systems. It strengthens the classical *Audet
reformulation* so that a reformulation can be verified through
explicit forward and backward mappings that preserve objective
ordering.

## Definition

Let $\mathcal{M} = (\mathcal{P}, \mathcal{F}, f_0)$ and
$\mathcal{M}' = (\mathcal{P}', \mathcal{F}', f'_0)$ be formulations. A
*reformulation construction* from $\mathcal{M}$ to $\mathcal{M}'$ is a
tuple
$\Phi(\mathcal{M}, \mathcal{M}') = (\Phi_{\mathrm{p}},\, \Phi_{\text{fwd}},\, \Phi_{\text{bwd}},\, \Phi_{\text{obj}})$
consisting of:

- a parameter mapping $\Phi_{\mathrm{p}} : \mathcal{P} \to \mathcal{P}'$,
- a forward mapping
  $\Phi_{\text{fwd}}(\cdot;p) : \mathbb{R}^{n(p)} \to \mathbb{R}^{n'(\Phi_{\mathrm{p}}(p))}$,
- a backward mapping
  $\Phi_{\text{bwd}}(\cdot;p) : \mathbb{R}^{n'(\Phi_{\mathrm{p}}(p))} \to \mathbb{R}^{n(p)}$
  computable in polynomial time, and
- an objective mapping $\Phi_{\text{obj}} : \mathbb{R} \to \mathbb{R}$.

$\mathcal{M}'$ is a *constructive reformulation* of $\mathcal{M}$ if
there exists a reformulation construction satisfying the following
conditions for every instance $p \in \mathcal{P}$, with
$p' = \Phi_{\mathrm{p}}(p)$:

- **Forward feasibility.** For all $x \in \mathcal{F}(p)$:
  $\Phi_{\text{fwd}}(x;p) \in \mathcal{F}'(p')$.
- **Backward feasibility.** For all $x' \in \mathcal{F}'(p')$:
  $\Phi_{\text{bwd}}(x';p) \in \mathcal{F}(p)$.
- **Strictly monotone objective mapping.** $\Phi_{\text{obj}}$ is
  strictly monotonically increasing.
- **Internal consistency.** For all $x \in \mathcal{F}(p)$,
  $f_0'(\Phi_{\text{fwd}}(x;p);p') = \Phi_{\text{obj}}(f_0(x;p))$, and
  for all $x' \in \mathcal{F}'(p')$,
  $f_0'(x';p') = \Phi_{\text{obj}}(f_0(\Phi_{\text{bwd}}(x';p);p))$.

This definition is stronger than *Audet reformulation* because it maps
*all* feasible points, not only optima. The stronger notion provides
more structure for automated proof systems while remaining satisfied
by common MILP transformations such as lifting, rescaling, and
substitution.

## Lean Encoding

`MILPReformulation F G` in `Common.lean` encodes a reformulation
construction from `F` to `G`. The fields correspond directly to the
components above: `paramMap` is $\Phi_{\mathrm{p}}$, `fwd` and `bwd`
are the forward and backward mappings, `objMap` is $\Phi_{\text{obj}}$
with monotonicity witnessed by `objMap_mono`, and `fwd_feas`,
`bwd_feas`, `fwd_obj`, `bwd_obj` discharge the four conditions.

```{literalinclude} ../../../../dataset/Common.lean
:language: lean
:start-at: structure MILPReformulation
```
