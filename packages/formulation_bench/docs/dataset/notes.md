# Per-Problem Notes

This page records, for each problem, the source it was adapted from and the
specific modifications, corrections, and added assumptions we applied.

```{note}
This page is in-progress; not every problem has detailed notes yet.
```

## p1 — EquivaFormulation Instance 47

- All variables in `problem_info.json` were incorrectly marked as continuous.
- Fixed typo in first constraint's LaTeX formulation in `47_c` and `47_d`
  (was mixing params × vars nonlinearly; corrected to match Gurobi code:
  $A \cdot s + K \cdot r \geq U$).
- Excluded instance-specific cutting plane (`47_e`).
- Added missing objective scaling to `problem_info` for the `_i`
  transformation (present in code but absent from `problem_info`).
- Implicit non-negativity assumption for every problem parameter.

## p2 — EquivaFormulation Instance 74

- All variables in `problem_info.json` were incorrectly marked as continuous.
- All variables in the solver code were also incorrectly marked as
  continuous, resulting in a fractional optimal solution.
- Binary substitution of decision variables was missing in the `_d`
  variation.
- No slack variables were introduced in the `_g` variation.
- Excluded instance-specific cutting plane (`74_e`).
- Implicit non-negativity assumption for every problem parameter and
  positivity assumption on `NumResources` and `NumExperiments`.
- Remove `_i` 1/10 scaling that prevents equivalence when the number of
  beakers becomes integer.

## p3 — EquivaFormulation Instance 92

- All variables in `problem_info.json` were incorrectly marked as continuous.
- All variables in the solver code were also incorrectly marked as
  continuous.
- Binary substitution of decision variables was missing in the `_d`
  variation.
- No slack variables were introduced in the `_g` variation.
- Excluded instance-specific cutting plane (`92_e`).
- Implicit non-negativity assumption for every problem parameter and
  positivity assumption on `NumBeakers`.
- Remove `_i` 1/10 scaling that prevents equivalence when the number of
  beakers becomes integer.

## p4 — EquivaFormulation Instance 183

- Replaced `"shape": ["Integer"]` with `type = "integer"` in `problem_info`.
- Bus variables in the `_d` binary substitution formulation were only
  represented with a single-digit variable.
- $S$ bus constraint upper bound was absent from `problem_info` (present in
  solver code at variable declaration); made into an explicit constraint and
  extended `_g` with an additional slack variable.
- Excluded instance-specific cutting plane (`183_e`).
- Added missing objective scaling to `problem_info` for the `_i`
  transformation (present in code but absent from `problem_info`).
- Implicit non-negativity assumption for every problem parameter.

## p5 — EquivaFormulation Instance 217

- All variables in `problem_info.json` were incorrectly marked as continuous.
- Excluded instance-specific cutting plane (`217_e`).
- Implicit non-negativity assumption for every problem parameter.

## p6 — Capacitated Warehouse Location Problem (CWLP)

*Source: EvoCut.*

- Formulation `p6.a` is the MILP formulation given in Section F.3 of the
  [v1 arXiv paper](https://arxiv.org/abs/2508.11850v1).
- We add implicit assumptions that sets $|I|, |J| > 0$ and parameters
  $u, f, c \geq 0$ and $d > 0$. *(TODO: why is $d > 0$ required?)*
- EvoCut [v1](https://arxiv.org/abs/2508.11850v1) proposes a hybrid
  inequality combining three lower bounds. We split this hybrid inequality
  into three separate inequalities to generate formulations `p6.c-d`.
- EvoCut [v2](https://arxiv.org/abs/2508.11850v2) proposes a family of five
  inequalities used to generate formulations `p6.e-j`.

## p7 — Rectangular Tiling with One Hole per Row and Column (IMO6)

*Source: EvoCut.*

- Formulation `p7.a` is the MILP formulation given in Section F.5 of the
  [v1 arXiv paper](https://arxiv.org/abs/2508.11850v1).
- We add an implicit assumption $N \ge 1$.
- EvoCut [v1](https://arxiv.org/abs/2508.11850v1) proposes a family of six
  inequalities used to generate formulations `p7.b-g`.
- EvoCut [v2](https://arxiv.org/abs/2508.11850v2) proposes two inequalities
  used to generate formulations `p7.h–i`.
- `p7.b` and `p7.c` (corresponding to EC1 and EC2 from
  [v1](https://arxiv.org/abs/2508.11850v1)) are identified as invalid
  inequalities. *(TODO: add small counter-examples.)*

## p8 — Job Shop Scheduling Problem (JSSP)

*Source: EvoCut.*

- Formulation `p8.a` is the MILP formulation given in Section F.4 of the
  [v1 arXiv paper](https://arxiv.org/abs/2508.11850v1). We make one
  modification to better match our Formulation JSON structure. The original
  formulation defines $\mathcal{P}$ as the set of distinct ordered pairs
  $(j_1, k_1), (j_2, k_2)$ that require the same machine. Instead, we
  define $Om_{j,k}$ to be the machine that the $k$-th operation of job $j$
  is assigned to.
- We add the following implicit assumptions: there is at least one job and
  machine, processing times $p_{j,k} \ge 0$, and $Om$ encodes a valid JSSP
  instance. To be a valid JSSP instance, each job has exactly one operation
  assigned per machine.
- EC1 is identical in v1 and v2 and is included once as formulation `p8.b`.
- EC2 is identical in v1 and v2 and is included once as formulation `p8.c`.
- v1 EC3 has an ambiguous interpretation; we exclude it from our dataset.
- v2 EC3 (longest job bound) is included as formulation `p8.d`.

## p9 — Multi-Commodity Network Design (MCND)

*Source: EvoCut.*

- Formulation `p9.a` is the MILP formulation given in Section F.2 of the
  [v1 arXiv paper](https://arxiv.org/abs/2508.11850v1). We make one
  notational change: the source indexes arcs as pairs $(i,j) \in A$; we
  instead index arcs by a single index $a$ with separate `tail` and `head`
  arrays, to match our Formulation JSON structure.
- We add implicit assumptions that arc costs $c_a, f_a \ge 0$, arc
  capacities $u_a \ge 0$, and commodity demands $d_k > 0$.
  *(TODO: why is $d_k > 0$ required?)*
- EvoCut [v1](https://arxiv.org/abs/2508.11850v1) proposes one inequality
  used to generate formulation `p9.b`.
- EvoCut [v2](https://arxiv.org/abs/2508.11850v2) proposes two inequalities
  used to generate formulations `p9.c` and `p9.d`.

## p10 — Pickup and Delivery Problem with Time Windows (PDPTW)

*Source: EvoCut.*

- Formulation `p10.a` is the MILP formulation given in Section F.5 of the
  [v2 arXiv paper](https://arxiv.org/abs/2508.11850v2).
- We add implicit assumptions that travel times
  $d^k_{0i}, d^k_{iH} \geq 0$ and $d_{ij} > 0$, time windows
  $\tau^-_i, \tau^+_i \ge 0$ with $\tau^-_i \geq \tau^+_i$, and that travel
  times satisfy the triangle inequalities $d^k_{0i} \le d^k_{0j} + d_{ji}$
  and $d_{ij} \le d_{im} + d_{mj}$.
- EvoCut [v2](https://arxiv.org/abs/2508.11850v2) proposes four inequalities
  used to generate formulations `p10.b-e`.

## p11 — Sub-Hour Unit Commitment (SHUC)

*Source: EvoCut.*

- Formulation `p11.a` is the MILP formulation given in Section F.7 of the
  [v2 arXiv paper](https://arxiv.org/abs/2508.11850v2).
- We add implicit assumptions covering non-empty sets, non-negativity of
  all parameters, and the ordering constraints $P^{\max}_g \ge P^{\min}_g$
  and $P^{w,\max}_{w,t} \ge P^{w,\min}_{w,t}$.
- The first three inequalities are a linearization defining an auxiliary
  variable $b_{g,t}$ as the product $v_{g,t} \cdot w_{g,t+1}$. We combine
  these three inequalities to form formulation `p11.b`.
- The remaining seven inequalities are used to form formulations `p11.c-i`.
  Notably, the inequality used in formulation `p11.e` relies on the
  auxiliary variable $b_{g,t}$. Hence, the three inequalities that define
  it are also included.

## p12 — Traveling Salesman Problem (TSP)

*Source: EvoCut.*

- Formulation `p12.a` is the Miller–Tucker–Zemlin (MTZ) MILP formulation
  given in Section F.1 of the
  [v1 arXiv paper](https://arxiv.org/abs/2508.11850v1).
- No implicit assumptions are added (the only problem in the dataset with
  no assumptions).
- EvoCut [v1](https://arxiv.org/abs/2508.11850v1) proposes three
  inequalities used to generate formulations `p12.b-d`.
- EvoCut [v2](https://arxiv.org/abs/2508.11850v2) proposes five inequalities
  used to generate formulations `p12.e-i`.
- `p12.d` (corresponding to EC3 of v1) is identified as an invalid
  inequality. The inequality
  $$x_{j1} + x_{ji} + u_j - u_i - 1 \leq (n-1)(2 - x_{1i} - x_{ij}) \quad \forall i, j \in V \setminus \{1\},\; i \neq j$$
  prevents the feasible $1 \to 2 \to 3 \to 1$ tour for $n=3$ TSP instances.
  `p12.f` (corresponding to EC2 of v2) is similarly invalid.
- `p12.e` (corresponding to EC1 of v2) is also identified as an invalid
  inequality. $x_{ij} + x_{ji} \leq 1$ eliminates the valid
  $1 \to 2 \to 1$ tour for $n=2$ TSP instances.

## p13 — Air Traffic Management

*Source: Ferchtandiker (2025).*

- Formulation `p13.a` is the time-indexed inefficient formulation and
  `p13.b` is the event-based efficient formulation.
- We add implicit assumptions that travel times $\tau_{a,a'} \geq 0$ and
  capacities $\mathrm{cap}_{a,t} \geq 0$.
- *(TODO: revisit this)* The capacity constraint in the source event-based
  formulation erroneously sums over all departure locations
  ($\sum_{p \in P} \sum_{a \in A} \sum_{a' \in A} x_{p,a,a',t} \leq \mathrm{cap}_{a,t}$);
  we correct this to sum only departures from location $a$
  ($\sum_{p \in P} \sum_{a' \in A} x_{p,a,a',t} \leq \mathrm{cap}_{a,t}$).
- ```{note}
  The `model.tex` files present in the dataset are simplifications of the
  models referenced in the description and data generation scripts. For
  this reason, we include the formulation pair in the dataset, but omit it
  from our results.
  ```

## p14 — Blood Bank Netherlands

*Source: Ferchtandiker (2025).*

- Formulation `p14.a` is the efficient formulation and `p14.b` is the
  inefficient formulation.
- In `p14.a`, we add explicit assumptions on the feasibility indicator
  $\delta_{ij}$ that enforce $\delta_{ij} \in \{0,1\}$ and $\delta_{ij} = 1$
  if and only if $T_{ij} \leq T_{\text{limit}}$. We also add implicit
  assumptions that sets are non-empty, travel times $T_{ij} \geq 0$,
  $T_{\text{limit}} \geq 0$, and $n \leq |\mathcal{S}|$.

## p15 — Dutch Housing Problem

*Source: Ferchtandiker (2025).*

- Formulation `p15.a` is the aggregate (efficient) formulation and `p15.b`
  is the disaggregate (inefficient) formulation.
- The source uses the floor area index $j$ directly as the area value
  (e.g., $j \cdot y_{ijh}$ in the average-area constraint). We introduce an
  explicit `area` array so that $\text{area}_j$ is the actual floor area
  for index $j$.
- In `p15.b`, the source uses $j_{v,a}$ directly as the area value of
  apartment $a$ in configuration $v$. We split this into a parameter
  $\text{jApt}_{v,a}$ giving the area index and `area` giving the value,
  consistent with `p15.a`.
- The source aggregate uses $a_i$ for the minimum sector fraction and the
  disaggregate uses $b_i$ for the same quantity. We preserve these distinct
  names in `p15.a` ($a_i$) and `p15.b` ($b_i$) respectively.
- The source uses $K$ as a scalar (floor count) in the aggregate and as a
  set of floors in the disaggregate. We use $K$ (scalar) in `p15.a` and
  rename to $nK$ (scalar) in `p15.b` so that $K = \{0, \dots, nK-1\}$ is
  the floor index set.
- `p15.a` and `p15.b` are not equivalent formulations of the same problem.
- We add implicit assumptions that all sets are non-empty,
  $R_{jv}, \text{area}_j, m_{ih}, a_i, s_i, o_h \geq 0$, and that `iFree`
  and `hCorp` are valid indices.

## p16 — Park and Bike Hub Location (Mobian)

*Source: Ferchtandiker (2025). Notes pending.*

## p17 — Open-Pit Mine Production Scheduling

*Source: Ferchtandiker (2025). Notes pending.*

## p18 — Timor-Leste Hospital Location

*Source: Ferchtandiker (2025). Notes pending.*

## p19 — UN Humanitarian Disaster Response Hub Location (UNHDR)

*Source: Ferchtandiker (2025). Notes pending.*

## p20 — World Food Program Food Distribution

*Source: Ferchtandiker (2025). Notes pending.*
