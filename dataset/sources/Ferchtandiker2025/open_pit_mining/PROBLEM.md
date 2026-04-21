# Open-Pit Mine Production Scheduling (OPMPS)

**Source:** `datasets/Ferchtandiker2025/open_pit_mining/efficient model.tex`, `datasets/Ferchtandiker2025/open_pit_mining/inefficient model.tex`, `datasets/Ferchtandiker2025/open_pit_mining/detailed description.txt`, `datasets/Ferchtandiker2025/open_pit_mining/dataset_description.txt`, `datasets/Ferchtandiker2025/open_pit_mining/vague description.txt`, `datasets/Ferchtandiker2025/open_pit_mining/data_generator.py`

## Summary

The Open-Pit Mine Production Scheduling problem determines, over a multi-period
planning horizon, when to extract each block of material (ore or waste) from an
open-pit mine in order to maximize the total discounted Net Present Value (NPV)
of the project. Each block has an associated ore tonnage, waste tonnage, and
ore grade; the schedule must respect per-period processing and mining capacity
bounds, blend ore grades within an acceptable window, and obey slope stability
(precedence) constraints that prevent a block from being mined before all
overlying blocks that must precede it.

## Formulations

### Inefficient

Every block is modeled with a binary decision variable $x_i^t \in \{0,1\}$
indicating whether block $i$ is mined in period $t$. This fully integer
formulation makes no distinction between blocks that are entirely ore
(grade $g_i = 1$) and blocks with mixed or lower grade.

#### Model

$$
\begin{aligned}
\max\;& \sum_{t=1}^{p} \sum_{i=1}^{n} c_i^t x_i^t \\[4pt]
\text{s.t.}\;
& \sum_{i=1}^{n} (g_i - G_{\max}) O_i x_i^t \leq 0, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (g_i - G_{\min}) O_i x_i^t \geq 0, && \forall t \in T \\[4pt]
& \sum_{t=1}^{p} x_i^t \leq 1, && \forall i \in I \\[4pt]
& \sum_{i=1}^{n} O_i x_i^t \leq PC_{\max}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} O_i x_i^t \geq PC_{\min}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (O_i + W_i) x_i^t \leq MC_{\max}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (O_i + W_i) x_i^t \geq MC_{\min}, && \forall t \in T \\[4pt]
& \sum_{\tau=1}^{t} x_i^{\tau} \geq x_j^t, && \forall t \in T,\; \forall i \in I,\; \forall j \in I \text{ with } P_{ij} = 1 \\[4pt]
& x_i^t \in \{0,1\}, && \forall i \in I,\; \forall t \in T
\end{aligned}.
$$

#### Notation

- $I = 1, \ldots, n$ (index $i$): set of blocks.
- $T = 1, \ldots, t$ (index $t$): set of scheduling periods.
- $c_i^t$: Net Present Value (NPV) of block $i$ in period $t$.
- $g_i$: grade of block $i$.
- $O_i$: ore tonnage of block $i$.
- $W_i$: waste tonnage of block $i$.
- $G_{\min}, G_{\max}$: minimum and maximum allowed average grade.
- $PC_{\min}, PC_{\max}$: per-period processing capacity lower and upper bounds.
- $MC_{\min}, MC_{\max}$: per-period mining capacity (ore + waste) lower and upper bounds.
- $P_{ij}$: precedence indicator; $P_{ij} = 1$ if block $i$ must be mined before block $j$, and $0$ otherwise.
- $x_i^t \in \{0,1\}$: decision variable that equals 1 iff block $i$ is mined in period $t$.

### Efficient

Blocks are partitioned into $I_1 = \{i \in I : g_i = 1\}$ (pure-ore blocks) and
$I_0 = \{i \in I : g_i < 1\}$ (mixed- or low-grade blocks). For $i \in I_0$
the decision $x_i^t$ remains binary, but for $i \in I_1$ it is relaxed to a
continuous fraction $x_i^t \in [0,1]$ representing the portion of block $i$
mined in period $t$. Because pure-ore blocks are homogeneous, splitting them
across periods does not change feasibility with respect to the grade blending
or capacity constraints, so the relaxation is exact and yields a smaller
mixed-integer program.

#### Model

$$
\begin{aligned}
\max\;& \sum_{t=1}^{p} \sum_{i=1}^{n} c_i^t x_i^t \\[4pt]
\text{s.t.}\;
& \sum_{i=1}^{n} (g_i - G_{\max}) O_i x_i^t \leq 0, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (g_i - G_{\min}) O_i x_i^t \geq 0, && \forall t \in T \\[4pt]
& \sum_{t=1}^{p} x_i^t \leq 1, && \forall i \in I \\[4pt]
& \sum_{i=1}^{n} O_i x_i^t \leq PC_{\max}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} O_i x_i^t \geq PC_{\min}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (O_i + W_i) x_i^t \leq MC_{\max}, && \forall t \in T \\[4pt]
& \sum_{i=1}^{n} (O_i + W_i) x_i^t \geq MC_{\min}, && \forall t \in T \\[4pt]
& \sum_{\tau=1}^{t} x_i^{\tau} \geq x_j^t, && \forall t \in T,\; \forall i \in I,\; \forall j \in I \text{ with } P_{ij} = 1 \\[4pt]
& x_i^t \in \{0,1\}, && \forall i \in I_0,\; \forall t \in T \\[4pt]
& x_i^t \in [0,1], && \forall i \in I_1,\; \forall t \in T
\end{aligned}.
$$

#### Notation

- $I = 1, \ldots, n$ (index $i$): set of blocks.
- $I_1 = \{i \in I : g_i = 1\}$: set of blocks with grade 1 (pure ore).
- $I_0 = \{i \in I : g_i < 1\}$: set of blocks with grade less than 1.
- $T = 1, \ldots, t$ (index $t$): set of scheduling periods.
- $c_i^t$: Net Present Value (NPV) of block $i$ in period $t$.
- $g_i$: grade of block $i$.
- $O_i$: ore tonnage of block $i$.
- $W_i$: waste tonnage of block $i$.
- $G_{\min}, G_{\max}$: minimum and maximum allowed average grade.
- $PC_{\min}, PC_{\max}$: per-period processing capacity lower and upper bounds.
- $MC_{\min}, MC_{\max}$: per-period mining capacity (ore + waste) lower and upper bounds.
- $P_{ij}$: precedence indicator; $P_{ij} = 1$ if block $i$ must be mined before block $j$, and $0$ otherwise.
- $x_i^t \in \{0,1\}$ for $i \in I_0$: decision variable that equals 1 iff block $i$ is mined in period $t$.
- $x_i^t \in [0,1]$ for $i \in I_1$: continuous decision variable representing the fraction of block $i$ mined in period $t$.
