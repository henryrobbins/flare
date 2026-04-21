# Job Shop Scheduling Problem (JSSP)

**Source:** `yazdani2025_v1` Section 13.4 and `yazdani2025_v2` Section 14.4

## Summary

The JSSP is a classic NP-hard combinatorial optimization problem,
typically formulated as a MILP. It involves scheduling a set of jobs on
multiple machines, where each job comprises a sequence of operations that
must be processed in a specified order on designated machines. The
objective is to minimize the makespan (the completion time of the last
operation), ensuring that each machine handles at most one operation at a
time.

## Formulation

### Model

$$
\begin{aligned}
\min\;& C_{\max} \\[4pt]
\text{s.t.}\;
& S_{j,k+1} \ge S_{j,k} + p_{j,k}
      &&\forall j,\; k = 1,\dots,n_{\text{mach}}-1 \\[6pt]
& S_{j_1,k_1} + p_{j_1,k_1} \le \\
  &\qquad S_{j_2,k_2} + M(1 - y_{j_1,k_1,j_2,k_2})
      &&\forall\, \bigl((j_1,k_1),(j_2,k_2)\bigr)\in\mathcal{P} \\[6pt]
& S_{j_2,k_2} + p_{j_2,k_2} \le \\
  &\qquad S_{j_1,k_1} + M\,y_{j_1,k_1,j_2,k_2}
      &&\forall\, \bigl((j_1,k_1),(j_2,k_2)\bigr)\in\mathcal{P} \\[6pt]
& C_{\max} \ge S_{j,n_{\text{mach}}} + p_{j,n_{\text{mach}}}
      &&\forall j \\[6pt]
& S_{j,k} \ge 0
      &&\forall j,k \\[2pt]
& y_{j_1,k_1,j_2,k_2}\in\{0,1\}
      &&\forall\, \bigl((j_1,k_1),(j_2,k_2)\bigr)\in\mathcal{P}
\end{aligned}.
$$

### Notation

- $n_{\text{mach}}$: number of machines (and operations per job), with $k\in\{1,\dots,n_{\text{mach}}\}$.
- $m\in\{1,\dots,n_{\text{mach}}\}$: machine index.
- $O$: set of all operations $(j,k)$.
- $O_m$: set of operations processed on machine $m$.
- $S_{j,k}\in\mathbb{R}_{\ge 0}$: start time of the $k$-th operation of job $j$.
- $p_{j,k}$: processing time of operation $(j,k)$.
- $\mathcal{P}$: set of ordered pairs $\bigl((j_1,k_1),(j_2,k_2)\bigr)$ of distinct operations that require the same machine; for every such pair exactly one of the two sequencing inequalities becomes active.
- $y_{j_1,k_1,j_2,k_2}\in\{0,1\}$: equals 1 if operation $(j_1,k_1)$ is scheduled before $(j_2,k_2)$ on their shared machine, 0 otherwise.
- $C_{\max}\in\mathbb{R}_{\ge 0}$: makespan (completion time of the last operation); the objective minimizes this value.
- $M$: a sufficiently large constant ("big-$M$") that deactivates the non-selected sequencing inequality.

## Cuts

### Version 1

#### EC1: Average Load Bound

The makespan is at least the average total processing time per machine.
$$C_{\max} \ge \frac{1}{m} \sum_{(j,k)\in O} p_{j,k}$$

#### EC2: Machine Critical-Path Bound

For each machine $m$, $\texttt{CP}_m$ sums the processing times of its operations plus the minimal cumulative processing times of operations that must precede and succeed them in their respective jobs.
$$C_{\max} \ge \max_m\bigl(\texttt{CP}_m\bigr)$$

#### EC3: Job Interference Bound

For each job $j$, $\texttt{Interf}_j$ sums the processing times of its operations plus the minimal processing times of conflicting operations from other jobs that share machines with $j$.
$$C_{\max} \ge \max_j\bigl(\texttt{Interf}_j\bigr)$$

### Version 2

#### EC1: Average Load Bound

The makespan is at least the average total processing time per machine.
$$C_{\max} \ge \frac{1}{n_{\text{mach}}} \sum_{(j,k)\in O} p_{j,k}$$

#### EC2: Machine Critical-Path Bound

Define the head and tail of operation $(j,k)$ as $h_{j,k} := \sum_{t<k} p_{j,t}$ and $\tau_{j,k} := \sum_{t>k} p_{j,t}$. Then $\texttt{CP}_m$ lower-bounds makespan by the total load on $m$ plus the earliest possible release of the first operation on $m$ and the smallest remaining tail after the last.
$$\texttt{CP}_m \;:=\; \sum_{(j,k)\in O_m} p_{j,k} \;+\; \min_{(j,k)\in O_m} h_{j,k} \;+\; \min_{(j,k)\in O_m} \tau_{j,k}$$
$$C_{\max} \ge \max_m\bigl(\texttt{CP}_m\bigr)$$

#### EC3: Longest Job Bound

The makespan is at least the total processing time of the longest job chain.
$$C_{\max} \ge \max_{j}\sum_{k} p_{j,k}$$
