A perfect graph with n vertices and m edges is given. The vertices are partitioned into P disjoint clusters, where every vertex belongs to exactly one cluster and each cluster contains at least one vertex.

Exactly one vertex must be selected from each of the P clusters. The selected vertices, together with the edges of the original graph that connect pairs of selected vertices, form an induced subgraph. The selected vertices must then be colored so that no two selected vertices sharing an edge receive the same color.

The goal is to choose one vertex per cluster and assign one color to each chosen vertex, respecting the edge-conflict rule above, so as to minimize the total number of distinct colors used across all selected vertices.
