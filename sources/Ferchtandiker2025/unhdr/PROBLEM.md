# UN Humanitarian Disaster Response Hub Location (UNHDR)

**Source:** `datasets/Ferchtandiker2025/unhdr/efficient model.tex`, `datasets/Ferchtandiker2025/unhdr/inefficient model.tex`, `datasets/Ferchtandiker2025/unhdr/detailed description.txt`, `datasets/Ferchtandiker2025/unhdr/vague description.txt`

## Summary

The UN Humanitarian Disaster Response (UNHDR) hub location problem designs a global pre-positioning network for humanitarian relief items. Given a set of candidate hubs (some of which are fixed and must remain open) and a set of disaster-prone regions with known affected populations, the decision maker selects at most $n$ hubs to open and routes supplies from opened hubs to every region so as to minimize total per-person transportation cost. Each region must have its demand fully met, the number of opened hubs is capped, and a (demand-weighted) travel time limit is enforced per region.

## Formulations

### Efficient

A compact formulation that represents the amount of supply shipped from each hub to each region by a single continuous variable $x_{hc}$. The per-region demand constraint $\sum_{h} x_{hc} = 1$ forces the $x_{hc}$ to behave as supply fractions, so no auxiliary assignment variable or big-M linking constraint is required.

#### Model

$$
\begin{aligned}
\min\;&\sum_{h \in H}\sum_{c \in C} a_c\,C_{hc}\,x_{hc}\\[3pt]
\text{s.t.}\;
&\sum_{c \in C} x_{hc} \le |C|\,y_h &&\forall h \in H\\
&\sum_{h \in H} x_{hc} = 1 &&\forall c \in C\\
&\sum_{h \in H} y_h \le n\\
&y_h = 1 &&\forall h \in H^f\\
&\sum_{h \in H} t_{hc}\,x_{hc} \le T &&\forall c \in C\\
&x_{hc} \in \mathbb{R}_+ &&\forall h \in H,\;c \in C\\
&y_h \in \{0,1\} &&\forall h \in H
\end{aligned}.
$$

#### Notation

- $H$ (index $h$): set of candidate hubs.
- $H^f \subseteq H$: set of fixed hubs that must be open.
- $C$ (index $c$): set of disaster regions.
- $|C|$: total number of disaster regions.
- $a_c$: total number of people affected in region $c$.
- $C_{hc}$: cost of transporting relief items for one affected person from hub $h$ to region $c$.
- $t_{hc}$: transportation time from hub $h$ to region $c$.
- $T$: maximum transportation time limit.
- $n$: maximum number of hubs that can be opened.
- $x_{hc} \ge 0$: amount of supply transported from hub $h$ to region $c$.
- $y_h \in \{0,1\}$: equals 1 iff hub $h$ is open.

### Inefficient

An expanded formulation that introduces a binary indicator $z_{hc}$ for whether hub $h$ contributes to region $c$'s demand, and a continuous demand-fraction variable $q_{hc}$, linked by a big-M constraint $q_{hc} \le M\,z_{hc}$. Unlike a strict single-assignment model, multiple hubs may serve a single region (matching the problem description, which requires each disaster region be served by *at least one* hub and which relies on cargo consolidation across multiple hubs). The extra indicator variable and big-M linkage weaken the LP relaxation relative to the efficient formulation.

#### Model

$$
\begin{aligned}
\min\;&\sum_{h \in H}\sum_{c \in C} a_c\,C_{hc}\,q_{hc}\\[3pt]
\text{s.t.}\;
&q_{hc} \le M\,z_{hc} &&\forall h \in H,\;c \in C\\
&\sum_{h \in H} q_{hc} = 1 &&\forall c \in C\\
&\sum_{c \in C} z_{hc} \le |C|\,y_h &&\forall h \in H\\
&\sum_{h \in H} y_h \le n\\
&y_h = 1 &&\forall h \in H^f\\
&\sum_{h \in H} t_{hc}\,q_{hc} \le T &&\forall c \in C\\
&q_{hc} \ge 0 &&\forall h \in H,\;c \in C\\
&z_{hc} \in \{0,1\} &&\forall h \in H,\;c \in C\\
&y_h \in \{0,1\} &&\forall h \in H
\end{aligned}.
$$

#### Notation

- $H$ (index $h$): set of candidate hubs.
- $H^f \subseteq H$: set of fixed hubs that must be open.
- $C$ (index $c$): set of disaster regions.
- $|C|$: total number of disaster regions.
- $a_c$: number of people affected in region $c$.
- $C_{hc}$: cost per person from hub $h$ to region $c$.
- $t_{hc}$: travel time from hub $h$ to region $c$.
- $T$: maximum allowed (weighted) travel time per region.
- $n$: maximum number of hubs that can be opened.
- $M$: sufficiently large constant used in the big-M linking constraint.
- $y_h \in \{0,1\}$: equals 1 iff hub $h$ is opened.
- $z_{hc} \in \{0,1\}$: equals 1 iff hub $h$ contributes any supply to region $c$.
- $q_{hc} \ge 0$: fraction of region $c$'s demand that is served by hub $h$.
