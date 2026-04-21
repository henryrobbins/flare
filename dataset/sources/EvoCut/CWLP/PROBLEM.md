# Capacitated Warehouse Location Problem (CWLP)

**Source:** `yazdani2025_v1` Section 13.3 and `yazdani2025_v2` Section 14.3

## Summary

The CWLP is an NP-hard combinatorial optimization problem, formulated as
a MILP. It involves selecting a subset of
candidate warehouse locations to open and assigning each customer to one
open warehouse. The problem is subjected to capacity constraints at each
facility, with the goal of minimizing total fixed opening and
transportation costs.

## Formulation

### Model

$$
\begin{aligned}
\min\;&\sum_{j\in J} f_j\,y_{j} \;+\; \sum_{i\in I}\sum_{j\in J} c_{ij}\,x_{ij} \\[4pt]
\text{s.t.}\;
&\sum_{j\in J} x_{ij} \;=\; 1 &&\forall i\in I \quad\text{(each customer is assigned)} \\[4pt]
&\sum_{i\in I} d_i\,x_{ij} \;\le\; u_j\,y_{j} &&\forall j\in J \quad\text{(capacity)}\\[4pt]
&x_{ij} \in \{0,1\} &&\forall i\in I,\, j\in J\\
&y_{j} \in \{0,1\} &&\forall j\in J
\end{aligned}.
$$

### Notation

- $I$ (index $i$): set of customers.
- $J$ (index $j$): set of candidate warehouses.
- $d_i$: demand of customer $i$.
- $u_j$: capacity of warehouse $j$.
- $f_j$: fixed cost to open warehouse $j$.
- $c_{ij}$: total transportation cost incurred if all of customer $i$'s demand is served by warehouse $j$ (so $c_{ij}$ already accounts for $d_i$).
- $y_j\in\{0,1\}$: decision variable that equals 1 iff warehouse $j$ is opened (0 otherwise).
- $x_{ij}\in\{0,1\}$: decision variable that equals 1 iff customer $i$ is assigned to warehouse $j$ (0 otherwise).

## Cuts

### Version 1

Let $D \;=\; \sum_{i\in I} d_i$ and $u_{j_1} \;\ge\; u_{j_2} \;\ge\; \dots \;\ge\; u_{j_{|J|}}$ be total demand and the capacities in non-increasing order.

#### EC1: Critical-Customer Bound

Let $C = \bigl\{\,i\in I : d_i > \tfrac12\max_{j\in J} u_j\bigr\}$ and $k_{\mathrm{crit}} = |C|$. $k_{\mathrm{crit}}$ is the number of customers whose demand exceeds half the capacity of the largest warehouse. Each of these customers must be alone.
$$\sum_{j\in J} y_j \;\ge\; k_{\mathrm{crit}}$$

#### EC2: Demand-Cover Bound

Let $k_{\mathrm{dem}} = \min\Bigl\{\,r : \sum_{\ell=1}^{r} u_{j_\ell} \,\ge\, D\Bigr\}$. $k_{\mathrm{dem}}$ is the minimum number of warehouses such that their combined capacity meets total demand.
$$\sum_{j\in J} y_j \;\ge\; k_{\mathrm{dem}}$$

#### EC3: $T$-Cover Bound

Let $T = \bigl\{\,j\in J : u_j \ge \max_{i\in I} d_i\bigr\}$ be the set of "large" facilities with sufficient capacity for the largest demand. Let $I_T = \bigl\{\,i\in I : d_i > \max_{j\notin T} u_j\bigr\}$ be the customers whose demand exceeds the max capacity of "small" facilities $j \notin T$. Lastly, let $k_T = \text{fewest } j\in T \text{ covering } \sum_{i\in I_T} d_i$. Large customers that cannot fit into "small" facilities force additional large facilities to open.
$$\sum_{j\in J} y_j \;\ge\; k_T$$

### Version 2

#### EC1: Demand Coverage

The total capacity of opened warehouses must cover demand.
$$\sum_{j\in J} u_j\,y_j \ge \sum_{i\in I} d_i$$

#### EC2: Global Slot Count Bounds

Let $\mathcal{V}\subseteq \{d_i:i\in I\}$ be a small set of demand thresholds. The cut enforces that enough warehouses are opened to provide a sufficient number of "slots" for customers at each demand threshold $v \in \mathcal{V}$.
$$\sum_{j\in J} \Bigl\lfloor \frac{u_j}{v}\Bigr\rfloor\,y_j \ge \bigl|\{i\in I : d_i\ge v\}\bigr| \qquad \forall v \in \mathcal{V}$$

#### EC3: Opening

If a customer is assigned to a warehouse, it must be opened.
$$x_{ij} \le y_j \qquad \forall i\in I,\;\forall j\in J$$

#### EC4: Assignment

If a customer's demand exceeds a warehouse's capacity, it cannot be assigned to that warehouse.
$$x_{ij} = 0 \qquad \forall i\in I,\;\forall j\in J\ \text{with } d_i>u_j$$

#### EC5: Warehouse Clique

$C_j\subseteq I$ is a lifted conflict set constructed
by starting from $\{i\in I: d_i>u_j/2\}$ and sequentially adding smaller
customers that still conflict with every customer already in the set (so
$d_i+d_{i'}>u_j$ for all distinct $i,i'\in C_j$).
$$\sum_{i\in C_j} x_{ij} \le y_j \qquad \forall j\in J$$

#### EC6: Warehouse Cover Inequality

For any warehouse $j$, at most 2 customers whose demand exceeds one-third of that warehouse's capacity can be assigned to it.
$$\sum_{i\in I : d_i>u_j/3} x_{ij} \le 2\,y_j \qquad \forall j\in J$$
