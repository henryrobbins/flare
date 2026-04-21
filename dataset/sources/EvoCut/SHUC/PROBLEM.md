# Sub-Hour Unit Commitment (SHUC)

**Source:** `yazdani2025_v2` Section 14.7

## Summary

The SHUC problem decides generator commitment (on/off) and dispatch
levels over a sub-hour horizon to meet demand and spinning reserve. It
is a practically motivated NP-hard problem that can be formulated as a
MILP with piecewise production costs, startup categories, ramping
limits, and minimum up and down times.

## Formulation

### Model

$$
\begin{aligned}
\min\;&\sum_{g\in G}\sum_{t\in \mathcal{T}} \bigl(c_{g,t} + C_{g,1}\,u_{g,t}\bigr)
      + \sum_{g\in G}\sum_{s\in S_g}\sum_{t\in \mathcal{T}} C^{su}_{g,s}\,d_{g,s,t} \\[4pt]
\text{s.t.}\;
&\sum_{g\in G} \bigl(p_{g,t} + P^{\min}_g\,u_{g,t}\bigr)
+ \sum_{w\in W} p^w_{w,t} = L_t
      &&\forall t\in \mathcal{T} \\[4pt]
&\sum_{g\in G} r_{g,t} \ge R_t
      &&\forall t\in \mathcal{T} \\[4pt]
&u_{g,t} - u_{g,t-1} = v_{g,t} - w_{g,t}
      &&\forall g\in G,\ t=2,\dots,T \\[4pt]
&\sum_{\tau=t-U_g+1}^{t} v_{g,\tau} \le u_{g,t}
      &&\forall g\in G,\ t\ge U_g \\[4pt]
&\sum_{\tau=t-D_g+1}^{t} w_{g,\tau} \le 1 - u_{g,t}
      &&\forall g\in G,\ t\ge D_g \\[4pt]
&v_{g,t} = \sum_{s\in S_g} d_{g,s,t}
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&d_{g,s,t} \le \sum_{i=\ell_{g,s}}^{\ell_{g,s+1}-1} w_{g,t-i}
      &&\forall g\in G,\ s<|S_g|,\ t\ge \ell_{g,s+1} \\[4pt]
&u_{g,t} \ge \mathrm{MR}_g
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&p_{g,t} + r_{g,t}
 \le (P^{\max}_g - P^{\min}_g)\,u_{g,t} - \max(P^{\max}_g - SU_g,0)\, v_{g,t}
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&p_{g,t} + r_{g,t}
 \le (P^{\max}_g - P^{\min}_g)\,u_{g,t} - \max(P^{\max}_g - SD_g,0)\, w_{g,t+1}
      &&\forall g\in G,\ t<T \\[4pt]
&p_{g,t} + r_{g,t} - p_{g,t-1} \le RU_g
      &&\forall g\in G,\ t=2,\dots,T \\[4pt]
&p_{g,t-1} - p_{g,t} \le RD_g
      &&\forall g\in G,\ t=2,\dots,T \\[4pt]
&p_{g,t} = \sum_{l\in L_g} (P_{g,l} - P_{g,1})\,\lambda_{g,l,t}
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&c_{g,t} = \sum_{l\in L_g} (C_{g,l} - C_{g,1})\,\lambda_{g,l,t}
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&u_{g,t} = \sum_{l\in L_g} \lambda_{g,l,t}
      &&\forall g\in G,\ t\in \mathcal{T} \\[4pt]
&P^{w,\min}_{w,t} \le p^w_{w,t} \le P^{w,\max}_{w,t}
      &&\forall w\in W,\ t\in \mathcal{T} \\[4pt]
&u_{g,t}, v_{g,t}, w_{g,t}, d_{g,s,t} \in \{0,1\},\ \lambda_{g,l,t}\in[0,1] \\[-1pt]
&p_{g,t}, r_{g,t}, c_{g,t}, p^w_{w,t} \ge 0
\end{aligned}.
$$

### Notation

- $\mathcal{T}=\{1,\dots,T\}$: time periods (index $t$).
- $G$: set of thermal generators; $W$: set of renewable generators.
- $S_g$: startup categories for generator $g$, with lag $\ell_{g,s}$ and cost $C^{su}_{g,s}$.
- $L_g$: piecewise production points $(P_{g,l}, C_{g,l})$, with $C_{g,1}$ the fixed on-cost per period.
- $L_t$, $R_t$: demand and spinning reserve requirements at time $t$.
- $P^{\min}_g$, $P^{\max}_g$: minimum and maximum thermal output; $P^{w,\min}_{w,t}$, $P^{w,\max}_{w,t}$: renewable output bounds.
- $RU_g$, $RD_g$: ramp-up and ramp-down limits; $SU_g$, $SD_g$: startup and shutdown ramp limits.
- $U_g$, $D_g$: minimum up and minimum down times; $\mathrm{MR}_g$: must-run flag.
- $u_{g,t}\in\{0,1\}$: on status; $v_{g,t}\in\{0,1\}$: startup; $w_{g,t}\in\{0,1\}$: shutdown.
- $p_{g,t}\ge 0$: thermal output above minimum; $r_{g,t}\ge 0$: spinning reserve; $p^w_{w,t}\ge 0$: renewable output.
- $d_{g,s,t}\in\{0,1\}$: startup category selection; $\lambda_{g,l,t}\in[0,1]$: piecewise weights; $c_{g,t}\ge 0$: variable production cost above the base cost.

## Cuts

The cuts introduce two auxiliary variables: $b_{g,t}\in\{0,1\}$, which equals 1 iff generator $g$ starts up at $t$ and immediately shuts down at $t{+}1$ (i.e. $v_{g,t}=w_{g,t+1}=1$), and $\overline{P}_{g,t}\ge 0$, the maximum output reachable by generator $g$ at time $t$ accounting for ramp limits and startup/shutdown derating.

#### EC1: Startup-Shutdown Indicator

The auxiliary variable $b_{g,t}$ linearizes the conjunction $v_{g,t}\wedge w_{g,t+1}$:
$$
\begin{aligned}
b_{g,t} &\;\le\; v_{g,t} \\
b_{g,t} &\;\le\; w_{g,t+1} \\
b_{g,t} &\;\ge\; v_{g,t} + w_{g,t+1} - 1
\end{aligned}
\qquad \forall g\in G,\ t<T.
$$

#### EC2a: Startup Derating Capacity Bound

Reachable output is reduced at startup by the startup ramp limit $SU_g$:
$$\overline{P}_{g,t} \;\le\; P^{\max}_g\,u_{g,t} - \max(P^{\max}_g - SU_g,\,0)\,v_{g,t} \qquad \forall g\in G,\ t\in \mathcal{T}.$$

#### EC2b: Shutdown Derating Capacity Bound

Reachable output is reduced the period before shutdown by the shutdown ramp limit $SD_g$:
$$\overline{P}_{g,t} \;\le\; P^{\max}_g\,u_{g,t} - \max(P^{\max}_g - SD_g,\,0)\,w_{g,t+1} \qquad \forall g\in G,\ t<T.$$

#### EC2c: Combined Startup-Shutdown Derating Capacity Bound

When both a startup and an immediate shutdown occur ($b_{g,t}=1$), double-derating is partially recovered:
$$\overline{P}_{g,t} \;\le\; P^{\max}_g\,u_{g,t} - \max(P^{\max}_g - SU_g,0)\,v_{g,t} - \max(P^{\max}_g - SD_g,0)\,w_{g,t+1} + \min\!\bigl(\max(P^{\max}_g - SU_g,0),\max(P^{\max}_g - SD_g,0)\bigr)\,b_{g,t} \qquad \forall g\in G,\ t<T.$$

#### EC3a: Ramp-Up Reachability from Previous Period

Reachable output is limited by the previous period's output plus the ramp-up rate, relaxed when the unit was offline:
$$\overline{P}_{g,t} \;\le\; P^{\min}_g\,u_{g,t} + p_{g,t-1} + RU_g + (P^{\max}_g - P^{\min}_g)\,(1-u_{g,t-1}) \qquad \forall g\in G,\ t=2,\dots,T.$$

#### EC3b: Ramp-Up Reachability with Previous-Period Startup Derating

When the unit started at $t{-}1$, its available output at $t$ is further limited by the startup ramp:
$$\overline{P}_{g,t} \;\le\; P^{\min}_g\,u_{g,t} + (P^{\max}_g - P^{\min}_g)\,u_{g,t-1} - \max(P^{\max}_g - SU_g,0)\,v_{g,t-1} + RU_g \qquad \forall g\in G,\ t=2,\dots,T.$$

#### EC3c: Ramp-Up Reachability with Current-Period Shutdown Derating

When the unit shuts down at $t$, its available output is limited by the shutdown ramp:
$$\overline{P}_{g,t} \;\le\; P^{\min}_g\,u_{g,t} + (P^{\max}_g - P^{\min}_g)\,u_{g,t-1} - \max(P^{\max}_g - SD_g,0)\,w_{g,t} + RU_g \qquad \forall g\in G,\ t=2,\dots,T.$$

#### EC4: Demand-Reserve Feasibility

Net demand (load minus renewables plus reserve) must be coverable by the total reachable thermal capacity:
$$L_t - \sum_{w\in W} p^w_{w,t} + R_t \;\le\; \sum_{g\in G} \overline{P}_{g,t} \qquad \forall t\in \mathcal{T}.$$
