# Formulation Definition

We make a clear distinction between a *formulation* and the parameter
(or data) values that define a particular *instance* of the problem.
Take the traveling salesman problem (TSP) as an example. A TSP
formulation is defined on an abstract set of cities. A TSP instance is
one such city set. Instantiating the formulation with an instance
yields a concrete MILP to be solved.

## Definition

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

## Lean Encoding

The `MILPFormulation` structure in `Common.lean` encodes the tuple
above. `Params` is the parameter space $\mathcal{P}$, `Vars p` is the
ambient variable space for instance $p$, `feasible p x` is the
indicator of $x \in \mathcal{F}(p)$, and `obj p x` is $f_0(x; p)$.

```{literalinclude} ../../../../dataset/Common.lean
:language: lean
:start-at: structure MILPFormulation
:end-before: structure MILPReformulation
```

Integrality and linearity are not baked into the structure; they are
expressed inside the `feasible` predicate of each concrete formulation
under `dataset/problems/`.
