import networkx as nx

# Constructing MILP graph from model.lp
G = nx.Graph()
G.add_node('R0', rhs=150.0, sense=0)
G.add_node('R1', rhs=100.0, sense=0)
G.add_node('R2', rhs=30.0, sense=0)
G.add_node('n[0]', cost=5.0, lb=0.0, ub=float('inf'), is_integer=0)
G.add_node('n[1]', cost=3.0, lb=0.0, ub=float('inf'), is_integer=0)
G.add_edge('R0', 'n[0]', weight=1.0)
G.add_edge('R0', 'n[1]', weight=1.0)
G.add_edge('R1', 'n[0]', weight=6.0)
G.add_edge('R1', 'n[1]', weight=3.0)
G.add_edge('R2', 'n[0]', weight=4.0)
G.add_edge('R2', 'n[1]', weight=2.0)

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