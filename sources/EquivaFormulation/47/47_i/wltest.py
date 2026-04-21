import networkx as nx

# Constructing MILP graph from model.lp
G = nx.Graph()
G.add_node('R0', rhs=500.0, sense=2)
G.add_node('R1', rhs=90.0, sense=0)
G.add_node('R2', rhs=0.0, sense=0)
G.add_node('r', cost=2.0, lb=0.0, ub=float('inf'), is_integer=1)
G.add_node('s', cost=2.0, lb=0.0, ub=float('inf'), is_integer=1)
G.add_edge('R0', 's', weight=20.0)
G.add_edge('R0', 'r', weight=30.0)
G.add_edge('R1', 's', weight=4.0)
G.add_edge('R1', 'r', weight=5.0)
G.add_edge('R2', 's', weight=-1.0)
G.add_edge('R2', 'r', weight=1.0)

# Prepare labels for WL
for n, data in G.nodes(data=True):
    if 'sense' in data and 'rhs' in data:
        # Constraint node
        G.nodes[n]['label'] = f"{data['rhs']}_{data['sense']}"
    else:
        # Variable node
        c = data['cost']
        lb = data['lb']
        ub = data['ub']
        isint = data['is_integer']
        G.nodes[n]['label'] = f"{c}_{lb}_{ub}_{isint}"

for u,v,data in G.edges(data=True):
    G[u][v]['label'] = str(data['weight'])

wl_hash = nx.weisfeiler_lehman_graph_hash(G, node_attr='label', edge_attr='label', iterations=2)
print('WL Hash:', wl_hash)