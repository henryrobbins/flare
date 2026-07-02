# Definitions

FormulationBench includes machine-checkable Lean 4 definitions of MILP
*formulation* and *reformulation* as defined in the {paper}`/`. Both
definitions are defined in `Common.lean`.

(formulation-definition)=
## MILP Formulation

We make a clear distinction between a *formulation* and the parameter
(or data) values that define a particular *instance* of the problem.
Take the traveling salesman problem (TSP) as an example. A TSP
formulation is defined on an abstract set of cities. A TSP instance is
one such city set. Instantiating the formulation with an instance
yields a concrete MILP to be solved.

### Definition

A MILP *formulation* $\mathcal{M}$ is a tuple
$\mathcal{M} = (\mathcal{P}, \mathcal{F}, f_0)$ with parameter space
$\mathcal{P}$, feasible region $\mathcal{F}(p) \subseteq \mathbb{R}^{n(p)}$,
and objective function $f_0$. For instance $p \in \mathcal{P}$, the
feasible region $\mathcal{F}(p)$ is defined by $m(p)$ linear constraints,
$f_i(\cdot ; p) : \mathbb{R}^{n(p)} \to \mathbb{R}$ for all
$i \in [m(p)]$. The first $k(p) \leq n(p)$ variables are integers. The
feasible region is

$$\mathcal{F}(p) = \{x \in \mathbb{Z}^{k(p)} \times \mathbb{R}^{n(p)-k(p)}~|~f_i(x;p) \leq 0 \; \forall i\in[m(p)]\}.$$

The objective is to minimize the linear function
$f_0(\cdot ; p) : \mathbb{R}^{n(p)} \to \mathbb{R}$. A formulation
$\mathcal{M}$ is *instantiated* with an *instance* $p \in \mathcal{P}$.
We denote an instantiated formulation as
$\mathcal{M}(p) = (\mathcal{F}(p), f_0(p))$.

### Lean Encoding

The `MILPFormulation` structure in `Common.lean` encodes the tuple
above. `Params` is the parameter space $\mathcal{P}$, `Vars p` is the
variable space for instance $p$, `feasible p x` is the
indicator of $x \in \mathcal{F}(p)$, and `obj p x` is $f_0(x; p)$.

```{literalinclude} ../../../dataset/Common.lean
:language: lean
:start-at: structure MILPFormulation
:end-before: structure MILPReformulation
```

:::{warning}
`MILPFormulation` does not restrict `Vars` to $\mathbb{R}^n$
nor does it assert linearity conditions on either `feasible` or `obj`. See the {paper}`/` for a further discussion.
:::

(reformulation-definition)=
## Reformulation

Reformulation has an intuitive operational meaning: $\mathcal{M}'$ is
a reformulation of $\mathcal{M}$ if one can map an instance
$\mathcal{M}(p)$ to an instance $\mathcal{M}'(p')$, solve
$\mathcal{M}'(p')$, and efficiently recover an optimal solution to
$\mathcal{M}(p)$. Importantly, this is a *formulation-level* claim
that holds across *all* problem instances $p \in \mathcal{P}$.
FormulationBench adopts a *constructive* definition of reformulation
that is amenable to formalization and tractable for automated
formal-proof systems.

### Definition

Let $\mathcal{M} = (\mathcal{P}, \mathcal{F}, f_0)$ and
$\mathcal{M}' = (\mathcal{P}', \mathcal{F}', f'_0)$ be formulations. A
*reformulation construction* from $\mathcal{M}$ to $\mathcal{M}'$ is a
tuple
$\Phi(\mathcal{M}, \mathcal{M}') = (\Phi_{\mathrm{p}},\, \Phi_{\text{fwd}},\, \Phi_{\text{bwd}},\, \Phi_{\text{obj}})$
consisting of:

- **Parameter mapping.** $\Phi_{\mathrm{p}} : \mathcal{P} \to \mathcal{P}'$.
- **Forward mapping.**
  $\Phi_{\text{fwd}}(\cdot;p) : \mathbb{R}^{n(p)} \to \mathbb{R}^{n'(\Phi_{\mathrm{p}}(p))}$.
- **Backward mapping.**
  $\Phi_{\text{bwd}}(\cdot;p) : \mathbb{R}^{n'(\Phi_{\mathrm{p}}(p))} \to \mathbb{R}^{n(p)}$ computable in polynomial time.
- **Objective mapping.** $\Phi_{\text{obj}} : \mathbb{R} \to \mathbb{R}$.

$\mathcal{M}'$ is a *constructive reformulation* of $\mathcal{M}$ if
there exists a reformulation construction satisfying the following
conditions for every instance $p \in \mathcal{P}$, with
$p' = \Phi_{\mathrm{p}}(p)$:

- **Forward feasibility.** For all $x \in \mathcal{F}(p)$:
  $\Phi_{\text{fwd}}(x;p) \in \mathcal{F}'(p')$.
- **Backward feasibility.** For all $x' \in \mathcal{F}'(p')$:
  $\Phi_{\text{bwd}}(x';p) \in \mathcal{F}(p)$.
- **Inverse consistency.** For all $x \in \mathcal{F}(p)$:
  $\Phi_{\text{bwd}}(\Phi_{\text{fwd}}(x;p);p) = x$.
- **Strictly monotone objective mapping.** $\Phi_{\text{obj}}$ is
  strictly monotonically increasing.
- **Objective preservation.** For all $x \in \mathcal{F}(p)$,
  $f_0'(\Phi_{\text{fwd}}(x;p);p') = \Phi_{\text{obj}}(f_0(x;p))$, and
  for all $x' \in \mathcal{F}'(p')$,
  $f_0'(x';p') = \Phi_{\text{obj}}(f_0(\Phi_{\text{bwd}}(x';p);p))$.

### Lean Encoding

`MILPReformulation F G` in `Common.lean` encodes a reformulation
construction from `F` to `G`. The fields correspond directly to the
components above: `paramMap` is $\Phi_{\mathrm{p}}$, `fwd` and `bwd`
are the forward and backward mappings, `objMap` is $\Phi_{\text{obj}}$
with monotonicity witnessed by `objMap_mono`. Lastly, `fwd_feas`,
`bwd_feas`, `bwd_fwd`, `fwd_obj`, and `bwd_obj` discharge the feasibility,
inverse-consistency, and objective-preservation conditions.

```{literalinclude} ../../../dataset/Common.lean
:language: lean
:start-at: structure MILPReformulation
```

:::{warning}
`MILPReformulation` omits the restriction that the backward mapping $\Phi_{\text{bwd}}$ is computable in polynomial time. See the {paper}`/` for a further discussion.
:::
