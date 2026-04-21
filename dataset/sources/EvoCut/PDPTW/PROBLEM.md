# Pickup and Delivery Problem with Time Windows (PDPTW)

**Source:** `yazdani2025_v2` Section 14.5

## Summary

The PDPTW is a vehicle routing problem in which each request consists of
a pickup location and a delivery location that must be served in
precedence order, subject to time window and vehicle capacity
constraints. The objective is to route vehicles to serve all requests
while minimizing total travel cost. PDPTW is NP-hard and admits MILP
formulations. The formulation models trucks and jobs as nodes in a
complete directed graph and permits explicit job rejection via self-loops
$x_{K+i,K+i}=1$ with penalty $d_{ii}$.

## Formulation

### Model

$$
\begin{aligned}
\min\;&\sum_{k=1}^{K}\sum_{i=1}^{N} d_{0i}^k\,x_{k,K+i}
      +\sum_{i=1}^{N}\sum_{j=1}^{N} d_{ij}\,x_{K+i,K+j}
      +\sum_{i=1}^{N}\sum_{k=1}^{K} d_{iH}^k\,x_{K+i,k}\\[4pt]
\text{s.t.}\;
&\sum_{v=1}^{K+N} x_{uv} = 1
      &&\forall u=1,\dots,K+N \\[4pt]
&\sum_{v=1}^{K+N} x_{vu} = 1
      &&\forall u=1,\dots,K+N \\[4pt]
&\delta_i - \sum_{k=1}^{K} (d_{0i}^k + v^k)\,x_{k,K+i} \ge 0
      &&\forall i=1,\dots,N \\[4pt]
&\delta_j - \delta_i - M\,x_{K+i,K+j} + (d_{ii}+d_{ij})\,x_{K+i,K+i} \ge d_{ii}+d_{ij}-M
      &&\forall i,j=1,\dots,N \\[4pt]
&\tau_i^{-} \le \delta_i \le \tau_i^{+}
      &&\forall i=1,\dots,N \\[4pt]
&\delta_i \in \mathbb{R}_{\ge 0}
      &&\forall i=1,\dots,N \\[4pt]
&x_{uv} \in \{0,1\}
      &&\forall u,v=1,\dots,K+N
\end{aligned}.
$$

### Notation

- $K$: number of trucks/vehicles in the fleet (truck nodes $k\in\{1,\dots,K\}$).
- $N$: number of pickup and delivery jobs (job nodes $K+i$ for $i\in\{1,\dots,N\}$).
- $u,v\in\{1,\dots,K+N\}$: node indices in the complete directed graph.
- $d_{ij}$: travel time from demand $i$'s return terminal to demand $j$'s pickup terminal; $d_{ii}$ is the loaded time of job $i$ and serves as its rejection penalty.
- $d_{0i}^k$: travel time from the home terminal of truck $k$ to demand $i$'s pickup terminal.
- $d_{iH}^k$: travel time from demand $i$'s return terminal to the home terminal of truck $k$.
- $v^k$: time at which truck $k$ becomes available.
- $\tau_i^{-},\tau_i^{+}$: earliest/latest permissible arrival times at demand $i$'s pickup terminal.
- $M$: big-$M$ constant.
- $x_{uv}\in\{0,1\}$: equals 1 iff arc $(u,v)$ is selected in the routing cycle cover.
- $\delta_i\in\mathbb{R}_{\ge 0}$: arrival time at demand $i$'s pickup terminal.

## Cuts

Let $\mathrm{EST}_i := \max\{\tau_i^{-},\,\min_{k}(v^k + d_{0i}^k)\}$ be the earliest possible arrival at demand $i$, and let $\mathcal{A}^{-} := \{(i,j) : \mathrm{EST}_i + d_{ii} + d_{ij} > \tau_j^{+}\}$ be the set of arc pairs that are infeasible due to time windows.

#### EC1: Arc Infeasibility

Any arc from job $i$ to job $j$ that cannot be traversed within the time windows is fixed to zero:
$$x_{K+i,K+j} = 0 \qquad \forall (i,j)\in \mathcal{A}^{-}.$$

#### EC2: Mutual Feasibility Pair

Let $\mathcal{F}_2 := \{(i,j) : i\neq j,\;(i,j)\notin\mathcal{A}^{-},\;(j,i)\notin\mathcal{A}^{-}\}$ be mutually feasible pairs. At most one of the two sequencing directions or a rejection of $i$ can hold simultaneously:
$$x_{K+i,K+j} + x_{K+j,K+i} + x_{K+i,K+i} \;\le\; 1 \qquad \forall (i,j)\in \mathcal{F}_2.$$

#### EC3: Clique Rejection

Let $\mathcal{C}$ be the set of cliques with $|C|>|K(C)|$ in the conflict graph that connects pairs with both directions infeasible, where $K(C):=\{k\in\{1,\dots,K\}:\exists\,i\in C\ \text{s.t.}\ v^k+d_{0i}^k\le\tau_i^{+}\}$ are the trucks that can reach at least one job in $C$ by its latest pickup time. The number of rejections within $C$ must cover the shortfall of reachable trucks:
$$\sum_{i\in C} x_{K+i,K+i} \;\ge\; |C|-|K(C)| \qquad \forall C\in \mathcal{C}.$$

#### EC4: Triple Infeasibility

Let $\mathcal{Q}$ be the set of triples $(i,k,j)$ with $(i,k)\notin\mathcal{A}^{-}$, $(k,j)\notin\mathcal{A}^{-}$, and $\max\{\mathrm{EST}_k,\,\mathrm{EST}_i+d_{ii}+d_{ik}\}+d_{kk}+d_{kj}>\tau_j^{+}$. Serving $k$ immediately after $i$ and then $j$ after $k$ is infeasible, so at least one of the three arcs must be absent:
$$x_{K+i,K+k} + x_{K+k,K+j} + x_{K+k,K+k} \;\le\; 1 \qquad \forall (i,k,j)\in \mathcal{Q}.$$
