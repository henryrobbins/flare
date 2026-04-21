import networkx as nx

# Constructing MILP graph from model.lp
G = nx.Graph()
G.add_node('R0', rhs=150.0, sense=1)
G.add_node('R1', rhs=10.0, sense=1)
G.add_node('R2', rhs=0.0, sense=1)
G.add_node('d', cost=6.0, lb=0.0, ub=float('inf'), is_integer=1)
G.add_node('h', cost=10.0, lb=0.0, ub=float('inf'), is_integer=1)
G.add_node('slack_0', cost=0.0, lb=0.0, ub=float('inf'), is_integer=0)
G.add_node('slack_1', cost=0.0, lb=0.0, ub=float('inf'), is_integer=0)
G.add_node('slack_2', cost=0.0, lb=0.0, ub=float('inf'), is_integer=0)
G.add_edge('R0', 'slack_1', weight=1.0)
G.add_edge('R0', 'h', weight=1.0)
G.add_edge('R0', 'd', weight=1.0)
G.add_edge('R1', 'slack_2', weight=-1.0)
G.add_edge('R1', 'd', weight=1.0)
G.add_edge('R2', 'slack_0', weight=1.0)
G.add_edge('R2', 'h', weight=-0.3)
G.add_edge('R2', 'd', weight=0.7)

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