# Rectangular Tiling with One Hole per Row and Column (IMO6)

**Source:** `yazdani2025_v1` Section 13.5 and `yazdani2025_v2` Section 14.6

## Summary

This problem is based on IMO 2025 Problem 6: given an $N\times N$ grid
of unit squares, place axis-aligned rectangular tiles (no overlaps) so
that each row and each column contains exactly one uncovered unit square
(a *hole*). The objective is to minimize the number of tiles used. We
model this with a 2D "interval$\times$flow" MILP.

## Formulation

### Model

$$
\begin{aligned}
\min\;&\sum_{i\in R}\;\sum_{(a,b)\in I} s_i^{ab} \\[4pt]
\text{s.t.}\;
&\sum_{j\in C} h_{ij} = 1
 &&\forall i\in R\\[-2pt]
& &&\text{(one hole per row)}\\[4pt]
&\sum_{i\in R} h_{ij} = 1
 &&\forall j\in C\\[-2pt]
& &&\text{(one hole per column)}\\[4pt]
&\sum_{\substack{(a,b)\in I\\ a\le j\le b}} x_i^{ab} + h_{ij} = 1
 &&\forall i\in R,\;\forall j\in C\\[-2pt]
& &&\text{(each cell covered at most once)}\\[4pt]
&x_{1}^{ab} - s_{1}^{ab} = 0
 &&\forall (a,b)\in I\\[-2pt]
& &&\text{(top flow)}\\[4pt]
&x_{i}^{ab} - x_{i-1}^{ab} - s_{i}^{ab} + t_{i-1}^{ab} = 0
 &&\forall i=2,\dots,N,\;\forall(a,b)\in I\\[-2pt]
& &&\text{(mid flow)}\\[4pt]
&x_{N}^{ab} - t_{N}^{ab} = 0
 &&\forall (a,b)\in I\\[-2pt]
& &&\text{(bottom flow)}\\[4pt]
&h_{ij}\in\{0,1\}
 &&\forall i\in R,\;\forall j\in C\\
&x_{i}^{ab},\,s_{i}^{ab},\,t_{i}^{ab}\in\{0,1\}
 &&\forall i\in R,\;\forall(a,b)\in I
\end{aligned}.
$$

### Notation

- $R=\{1,\dots,N\}$, $C=\{1,\dots,N\}$: row and column index sets ($i\in R$, $j\in C$).
- $I=\{(a,b)\in C^2:\ a\le b\}$: all contiguous column-intervals (index $(a,b)$).
- $h_{ij}\in\{0,1\}$: $=1$ iff $(i,j)$ is the unique hole in row $i$ and in column $j$.
- $x_i^{ab}\in\{0,1\}$: $=1$ iff on row $i$ the columns $a,a{+}1,\dots,b$ are covered by the same tile.
- $s_i^{ab},t_i^{ab}\in\{0,1\}$: start/end flags of the vertical strip for interval $(a,b)$ at row $i$; the number of rectangles equals $\sum_{i,(a,b)} s_i^{ab}$.

## Cuts

### Version 1

#### EC1: Horizontal-Left Break

For each row $i$ and each column $j \in \{2,\dots,N\}$, the hole at $(i,j)$ forces an interval to end immediately to its left:
$$h_{ij} \;\le\; \sum_{\substack{(a,b)\in I\\ b=j-1}} t_i^{ab} \qquad \forall i\in R,\ \forall j\in\{2,\dots,N\}.$$

#### EC2: Horizontal-Right Break

For each row $i$ and each column $j \in \{1,\dots,N-1\}$, the hole at $(i,j)$ forces an interval to start immediately to its right:
$$h_{ij} \;\le\; \sum_{\substack{(a,b)\in I\\ a=j+1}} s_i^{ab} \qquad \forall i\in R,\ \forall j\in\{1,\dots,N-1\}.$$

#### EC3: Top-Row Vertical Break

A hole in the first row forces a vertical strip to start in row 2 over the same column span:
$$h_{1j} \;\le\; \sum_{\substack{(a,b)\in I\\ a\le j\le b}} s_{2}^{ab} \qquad \forall j\in C.$$

#### EC4: Bottom-Row Vertical Break

A hole in the last row forces a vertical strip to end in row $N-1$ over the same column span:
$$h_{Nj} \;\le\; \sum_{\substack{(a,b)\in I\\ a\le j\le b}} t_{N-1}^{ab} \qquad \forall j\in C.$$

#### EC5: Interior Vertical-Above Break

For an interior hole at row $i \in \{2,\dots,N-1\}$, a vertical strip covering that column span must end in row $i-1$:
$$h_{ij} \;\le\; \sum_{\substack{(a,b)\in I\\ a\le j\le b}} t_{i-1}^{ab} \qquad \forall i\in\{2,\dots,N{-}1\},\ \forall j\in C.$$

#### EC6: Interior Vertical-Below Break

For an interior hole at row $i \in \{2,\dots,N-1\}$, a vertical strip covering that column span must start in row $i+1$:
$$h_{ij} \;\le\; \sum_{\substack{(a,b)\in I\\ a\le j\le b}} s_{i+1}^{ab} \qquad \forall i\in\{2,\dots,N{-}1\},\ \forall j\in C.$$

### Version 2

#### EC1: Vacated Column

If the hole leaves column $j$ between row $i{-}1$ and row $i$, then column $j$ must be covered by an interval that starts at row $i$:
$$\sum_{\substack{(a,b)\in I\\ a\le j\le b}} s_i^{ab} \;\ge\; h_{i-1,j} - h_{ij} \qquad \forall i\in\{2,\dots,N\},\ \forall j\in C.$$

#### EC2: Broken Interval

If columns $j$ and $k$ were covered by the same interval on row $i{-}1$ and the hole appears at column $k$ on row $i$, then coverage at column $j$ must start anew at row $i$:
$$\sum_{\substack{(a,b)\in I\\ a\le j\le b}} s_i^{ab} \;\ge\; \sum_{\substack{(a,b)\in I\\ a\le \min\{j,k\}\\ b\ge \max\{j,k\}}} x_{i-1}^{ab} + h_{ik} - 1 \qquad \forall i\in\{2,\dots,N\},\ \forall j,k\in C,\ j\neq k.$$
