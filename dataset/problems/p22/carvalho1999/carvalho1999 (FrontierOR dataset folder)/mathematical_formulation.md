# Original Formulation: One-Dimensional Bin-Packing – Arc Flow Model (Arc Flow)

*Source: Exact solution of bin-packing problems using column generation and branch-and-bound, J.M. Valério de Carvalho, Annals of Operations Research 86 (1999) 629–659.*

## Sets and Indices

$$\begin{align*}
V &= \{0, 1, 2, \ldots, W\} && \text{set of vertices of the graph } G=(V,A) \\
A &= \{(i,j) : 0 \le i < j \le W,\ j - i = w_d \text{ for some } d \le m\} && \text{item arcs} \\
  &\quad \cup\ \{(k, k+1) : k = 0, 1, \ldots, W-1\} && \text{loss arcs} \\
d &= 1, 2, \ldots, m && \text{index over the different item sizes}
\end{align*}$$

## Parameters

$$\begin{align*}
W   &\quad \text{bin capacity (positive integer)} \\
m   &\quad \text{number of different item sizes} \\
w_d &\quad \text{size of item type } d,\ d = 1,\ldots,m,\ \ 0 \le w_d \le W \\
b_d &\quad \text{demand (number of items required) of type } d,\ d = 1,\ldots,m
\end{align*}$$

## Decision Variables

$$\begin{align*}
x_{ij} &\quad \text{flow on arc } (i,j) \in A:\ \text{number of items of size } j-i \\
       &\quad \text{placed in any bin at a distance } i \text{ from the beginning of the bin} \\
z      &\quad \text{feedback arc flow from vertex } W \text{ to vertex } 0\ (z = x_{W0});\ \text{number of bins used}
\end{align*}$$

## Objective

$$\begin{align}
\text{minimize} \quad z \tag{7}
\end{align}$$

## Constraints

$$\begin{align}
\sum_{(i,j) \in A} x_{ij} \;-\; \sum_{(j,k) \in A} x_{jk} &=
\begin{cases}
-z, & \text{if } j = 0, \\
\phantom{-}0, & \text{if } j = 1, 2, \ldots, W-1, \\
\phantom{-}z, & \text{if } j = W;
\end{cases}
\tag{8} \\[1ex]
\sum_{(k,\, k+w_d) \in A} x_{k,\, k+w_d} &\ge b_d, \quad d = 1, 2, \ldots, m, \tag{9} \\[1ex]
x_{ij} &\ge 0, \quad \forall (i,j) \in A, \tag{10} \\[1ex]
x_{ij} &\ \text{integer}, \quad \forall (i,j) \in A. \tag{11}
\end{align}$$
