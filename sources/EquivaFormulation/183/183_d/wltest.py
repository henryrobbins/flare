import networkx as nx

# Constructing MILP graph from model.lp
G = nx.Graph()
G.add_node('R0', rhs=300.0, sense=2)
G.add_node('h_0', cost=30.0, lb=0, ub=9.0, is_integer=1)
G.add_node('m_0', cost=10.0, lb=0, ub=9.0, is_integer=1)
G.add_node('m_1', cost=100.0, lb=0, ub=9.0, is_integer=1)
G.add_edge('R0', 'm_0', weight=4.0)
G.add_edge('R0', 'm_1', weight=40.0)
G.add_edge('R0', 'h_0', weight=20.0)

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