import random
import numpy as np
import json

# from datasets.world_food_program.dataset import WFPDataset   # Not needed for pure JSON

def generate_data(seed=42, output_path='src/datasets/world_food_program/large_data.json'):
    random.seed(seed)
    np.random.seed(seed)
    
    # Sets
    nutrients = [
        # Macronutrients
        'calories', 'protein', 'fat', 'carbohydrates', 'fiber', 'sugar',
        
        # Vitamins
        'vitaminA', 'vitaminC', 'vitaminD', 'vitaminE', 'vitaminK',
        'vitaminB1', 'vitaminB2', 'vitaminB3', 'vitaminB5', 'vitaminB6', 'vitaminB7', 'vitaminB9', 'vitaminB12',
        
        # Minerals
        'calcium', 'iron', 'magnesium', 'phosphorus', 'potassium', 'sodium', 'zinc',
        'copper', 'manganese', 'selenium', 'chromium', 'molybdenum', 'iodine',
        
        # Other nutrients
        'omega3', 'omega6', 'cholesterol', 'saturated_fat', 'trans_fat', 'monounsaturated_fat', 'polyunsaturated_fat'
    ]
    foods = [f"food_{i:03d}" for i in range(1, 51)]
    beneficiary_nodes = [f'B{i}' for i in range(1, 10)]
    supplier_nodes = [f'S{i}' for i in range(1, 11)]
    transshipment_nodes = [f'T{i}' for i in range(1, 30)]
    nodes = supplier_nodes + transshipment_nodes + beneficiary_nodes

    # Edges (multi-dimensional dict)
    edges = {i: {j: 0 for j in nodes} for i in nodes}
    
    # Define edge creation and removal probabilities
    edge_configs = [
        (supplier_nodes, transshipment_nodes, 1.0, 0.2),      # S-T: create all, remove 20%
        (transshipment_nodes, transshipment_nodes, 1.0, 0.3), # T-T: create all, remove 30%
        (transshipment_nodes, beneficiary_nodes, 1.0, 0.15),  # T-B: create all, remove 15%
        (supplier_nodes, beneficiary_nodes, 1.0, 0.25)        # S-B: create all, remove 25%
    ]
    
    # Create and remove edges based on configuration
    for source_nodes, target_nodes, create_prob, remove_prob in edge_configs:
        for source in source_nodes:
            for target in target_nodes:
                if source != target:  # Avoid self-loops
                    edges[source][target] = 1
                    if random.random() < remove_prob:
                        edges[source][target] = 0

    # Paths
    paths = []
    for s in supplier_nodes:
        for b in beneficiary_nodes:
            if edges[s][b] == 1:  # Only add direct paths that exist
                paths.append(f"{s}-{b}")
    for s in supplier_nodes:
        for t in transshipment_nodes:
            for b in beneficiary_nodes:
                if edges[s][t] == 1 and edges[t][b] == 1:  # Only add paths where both edges exist
                    paths.append(f"{s}-{t}-{b}")
    for s in supplier_nodes:
        for t1 in transshipment_nodes:
            for t2 in transshipment_nodes:
                if t1 != t2:
                    for b in beneficiary_nodes:
                        if edges[s][t1] == 1 and edges[t1][t2] == 1 and edges[t2][b] == 1:  # Only add paths where all edges exist
                            paths.append(f"{s}-{t1}-{t2}-{b}")

    # Parameters
    number_of_beneficiaries = {b: random.randint(15000, 200000) for b in beneficiary_nodes}
    nutricial_requirements = {
        # Macronutrients (daily requirements)
        'calories': 2500,
        'protein': 56,  # grams
        'fat': 65,  # grams
        'carbohydrates': 275,  # grams
        'fiber': 28,  # grams
        'sugar': 50,  # grams (added sugar limit)
        
        # Vitamins (daily requirements)
        'vitaminA': 0.9,  # mg
        'vitaminC': 90,  # mg
        'vitaminD': 0.015,  # mg
        'vitaminE': 15,  # mg
        'vitaminK': 0.12,  # mg
        'vitaminB1': 1.2,  # mg (thiamine)
        'vitaminB2': 1.3,  # mg (riboflavin)
        'vitaminB3': 16,  # mg (niacin)
        'vitaminB5': 5,  # mg (pantothenic acid)
        'vitaminB6': 1.3,  # mg
        'vitaminB7': 0.03,  # mg (biotin)
        'vitaminB9': 0.4,  # mg (folate)
        'vitaminB12': 0.0024,  # mg
        
        # Minerals (daily requirements)
        'calcium': 1000,  # mg
        'iron': 14,  # mg
        'magnesium': 400,  # mg
        'phosphorus': 700,  # mg
        'potassium': 3500,  # mg
        'sodium': 2300,  # mg (limit)
        'zinc': 11,  # mg
        'copper': 0.9,  # mg
        'manganese': 2.3,  # mg
        'selenium': 0.055,  # mg
        'chromium': 0.035,  # mg
        'molybdenum': 0.045,  # mg
        'iodine': 0.15,  # mg
        
        # Other nutrients
        'omega3': 1.6,  # grams
        'omega6': 17,  # grams
        'cholesterol': 300,  # mg (limit)
        'saturated_fat': 20,  # grams (limit)
        'trans_fat': 2,  # grams (limit)
        'monounsaturated_fat': 25,  # grams
        'polyunsaturated_fat': 25  # grams
    }

    # Nutritional values (nested dict)
    nutritional_values = {k: {} for k in foods}
    for k in foods:
        for l in nutrients:
            food_type = int(k.split('_')[1])
            if food_type % 5 == 0:  # Grains/Cereals
                values = {
                    'calories': random.randint(3200, 3600), 'protein': random.randint(40, 60), 'fat': random.randint(2, 8), 
                    'carbohydrates': random.randint(650, 750), 'fiber': random.randint(25, 35), 'sugar': random.randint(5, 15),
                    'vitaminA': random.uniform(0.0, 0.05), 'vitaminC': random.uniform(0.0, 2.0), 'vitaminD': random.uniform(0.0, 0.001), 
                    'vitaminE': random.uniform(0.5, 2.0), 'vitaminK': random.uniform(0.001, 0.005), 'vitaminB1': random.uniform(0.8, 1.5), 
                    'vitaminB2': random.uniform(0.3, 0.8), 'vitaminB3': random.uniform(8, 15), 'vitaminB5': random.uniform(3, 7), 
                    'vitaminB6': random.uniform(0.8, 1.5), 'vitaminB7': random.uniform(0.02, 0.04), 'vitaminB9': random.uniform(0.0, 0.05), 
                    'vitaminB12': random.uniform(0.0, 0.0005), 'calcium': random.uniform(20, 50), 'iron': random.uniform(1.0, 2.0), 
                    'magnesium': random.uniform(100, 200), 'phosphorus': random.uniform(300, 500), 'potassium': random.uniform(300, 600), 
                    'sodium': random.uniform(5, 20), 'zinc': random.uniform(1.0, 2.0), 'copper': random.uniform(0.3, 0.8), 
                    'manganese': random.uniform(2.0, 4.0), 'selenium': random.uniform(0.02, 0.05), 'chromium': random.uniform(0.01, 0.03), 
                    'molybdenum': random.uniform(0.02, 0.04), 'iodine': random.uniform(0.01, 0.05), 'omega3': random.uniform(0.1, 0.5), 
                    'omega6': random.uniform(2.0, 5.0), 'cholesterol': random.uniform(0, 5), 'saturated_fat': random.uniform(0.5, 2.0), 
                    'trans_fat': random.uniform(0, 0.1), 'monounsaturated_fat': random.uniform(0.5, 2.0), 'polyunsaturated_fat': random.uniform(1.0, 3.0)
                }
            elif food_type % 5 == 1:  # Meat/Fish
                values = {
                    'calories': random.randint(3000, 3500), 'protein': random.randint(120, 180), 'fat': random.randint(20, 50), 
                    'carbohydrates': random.randint(0, 10), 'fiber': random.randint(0, 2), 'sugar': random.randint(0, 2),
                    'vitaminA': random.uniform(0.1, 0.5), 'vitaminC': random.uniform(5, 15), 'vitaminD': random.uniform(0.005, 0.02), 
                    'vitaminE': random.uniform(1.0, 3.0), 'vitaminK': random.uniform(0.01, 0.05), 'vitaminB1': random.uniform(0.5, 1.2), 
                    'vitaminB2': random.uniform(1.0, 2.0), 'vitaminB3': random.uniform(15, 25), 'vitaminB5': random.uniform(4, 8), 
                    'vitaminB6': random.uniform(1.0, 2.0), 'vitaminB7': random.uniform(0.02, 0.05), 'vitaminB9': random.uniform(0.1, 0.3), 
                    'vitaminB12': random.uniform(0.001, 0.002), 'calcium': random.uniform(10, 30), 'iron': random.uniform(8, 15), 
                    'magnesium': random.uniform(200, 350), 'phosphorus': random.uniform(400, 600), 'potassium': random.uniform(800, 1200), 
                    'sodium': random.uniform(50, 150), 'zinc': random.uniform(10, 20), 'copper': random.uniform(0.5, 1.5), 
                    'manganese': random.uniform(0.1, 0.5), 'selenium': random.uniform(0.03, 0.08), 'chromium': random.uniform(0.02, 0.05), 
                    'molybdenum': random.uniform(0.03, 0.06), 'iodine': random.uniform(0.05, 0.15), 'omega3': random.uniform(0.5, 2.0), 
                    'omega6': random.uniform(1.0, 3.0), 'cholesterol': random.uniform(50, 150), 'saturated_fat': random.uniform(5, 15), 
                    'trans_fat': random.uniform(0, 0.5), 'monounsaturated_fat': random.uniform(8, 20), 'polyunsaturated_fat': random.uniform(2, 8)
                }
            elif food_type % 5 == 2:  # Legumes/Beans
                values = {
                    'calories': random.randint(3400, 3800), 'protein': random.randint(100, 150), 'fat': random.randint(20, 40), 
                    'carbohydrates': random.randint(600, 700), 'fiber': random.randint(40, 60), 'sugar': random.randint(10, 25),
                    'vitaminA': random.uniform(0.5, 1.0), 'vitaminC': random.uniform(15, 30), 'vitaminD': random.uniform(0.0, 0.001), 
                    'vitaminE': random.uniform(2.0, 5.0), 'vitaminK': random.uniform(0.02, 0.08), 'vitaminB1': random.uniform(1.0, 2.0), 
                    'vitaminB2': random.uniform(0.8, 1.5), 'vitaminB3': random.uniform(12, 20), 'vitaminB5': random.uniform(5, 10), 
                    'vitaminB6': random.uniform(1.2, 2.0), 'vitaminB7': random.uniform(0.03, 0.06), 'vitaminB9': random.uniform(0.3, 0.5), 
                    'vitaminB12': random.uniform(0.001, 0.002), 'calcium': random.uniform(100, 200), 'iron': random.uniform(20, 35), 
                    'magnesium': random.uniform(300, 500), 'phosphorus': random.uniform(500, 800), 'potassium': random.uniform(1200, 1800), 
                    'sodium': random.uniform(10, 30), 'zinc': random.uniform(15, 25), 'copper': random.uniform(1.0, 2.0), 
                    'manganese': random.uniform(3.0, 6.0), 'selenium': random.uniform(0.04, 0.08), 'chromium': random.uniform(0.02, 0.05), 
                    'molybdenum': random.uniform(0.04, 0.08), 'iodine': random.uniform(0.02, 0.08), 'omega3': random.uniform(0.3, 1.0), 
                    'omega6': random.uniform(3.0, 8.0), 'cholesterol': random.uniform(0, 5), 'saturated_fat': random.uniform(2, 6), 
                    'trans_fat': random.uniform(0, 0.1), 'monounsaturated_fat': random.uniform(5, 12), 'polyunsaturated_fat': random.uniform(8, 15)
                }
            elif food_type % 5 == 3:  # Oils/Fats
                values = {
                    'calories': random.randint(8000, 8500), 'protein': random.randint(0, 5), 'fat': random.randint(800, 900), 
                    'carbohydrates': random.randint(0, 5), 'fiber': random.randint(0, 2), 'sugar': random.randint(0, 2),
                    'vitaminA': random.uniform(0.4, 0.8), 'vitaminC': random.uniform(0.0, 2.0), 'vitaminD': random.uniform(0.01, 0.03), 
                    'vitaminE': random.uniform(10, 25), 'vitaminK': random.uniform(0.05, 0.15), 'vitaminB1': random.uniform(0.0, 0.1), 
                    'vitaminB2': random.uniform(0.0, 0.1), 'vitaminB3': random.uniform(0.0, 0.5), 'vitaminB5': random.uniform(0.0, 0.5), 
                    'vitaminB6': random.uniform(0.0, 0.1), 'vitaminB7': random.uniform(0.0, 0.01), 'vitaminB9': random.uniform(0.0, 0.05), 
                    'vitaminB12': random.uniform(0.0, 0.0005), 'calcium': random.uniform(5, 20), 'iron': random.uniform(0.0, 0.5), 
                    'magnesium': random.uniform(10, 30), 'phosphorus': random.uniform(10, 30), 'potassium': random.uniform(50, 150), 
                    'sodium': random.uniform(0, 10), 'zinc': random.uniform(0.0, 0.5), 'copper': random.uniform(0.0, 0.2), 
                    'manganese': random.uniform(0.0, 0.5), 'selenium': random.uniform(0.0, 0.02), 'chromium': random.uniform(0.0, 0.01), 
                    'molybdenum': random.uniform(0.0, 0.02), 'iodine': random.uniform(0.0, 0.05), 'omega3': random.uniform(1.0, 5.0), 
                    'omega6': random.uniform(20, 50), 'cholesterol': random.uniform(0, 50), 'saturated_fat': random.uniform(50, 150), 
                    'trans_fat': random.uniform(0, 2), 'monounsaturated_fat': random.uniform(200, 400), 'polyunsaturated_fat': random.uniform(100, 300)
                }
            else:  # Dairy/Eggs
                values = {
                    'calories': random.randint(3800, 4200), 'protein': random.randint(60, 100), 'fat': random.randint(80, 120), 
                    'carbohydrates': random.randint(50, 100), 'fiber': random.randint(0, 5), 'sugar': random.randint(20, 40),
                    'vitaminA': random.uniform(0.4, 0.8), 'vitaminC': random.uniform(10, 25), 'vitaminD': random.uniform(0.01, 0.02), 
                    'vitaminE': random.uniform(2.0, 5.0), 'vitaminK': random.uniform(0.02, 0.08), 'vitaminB1': random.uniform(0.8, 1.5), 
                    'vitaminB2': random.uniform(1.5, 2.5), 'vitaminB3': random.uniform(10, 18), 'vitaminB5': random.uniform(4, 8), 
                    'vitaminB6': random.uniform(1.0, 1.8), 'vitaminB7': random.uniform(0.02, 0.05), 'vitaminB9': random.uniform(0.1, 0.3), 
                    'vitaminB12': random.uniform(0.0008, 0.002), 'calcium': random.uniform(800, 1200), 'iron': random.uniform(10, 18), 
                    'magnesium': random.uniform(200, 350), 'phosphorus': random.uniform(600, 900), 'potassium': random.uniform(1000, 1500), 
                    'sodium': random.uniform(200, 400), 'zinc': random.uniform(8, 15), 'copper': random.uniform(0.3, 0.8), 
                    'manganese': random.uniform(0.5, 1.5), 'selenium': random.uniform(0.03, 0.08), 'chromium': random.uniform(0.02, 0.05), 
                    'molybdenum': random.uniform(0.03, 0.06), 'iodine': random.uniform(0.05, 0.15), 'omega3': random.uniform(0.2, 1.0), 
                    'omega6': random.uniform(2.0, 6.0), 'cholesterol': random.uniform(200, 400), 'saturated_fat': random.uniform(30, 60), 
                    'trans_fat': random.uniform(0.5, 2.0), 'monounsaturated_fat': random.uniform(20, 40), 'polyunsaturated_fat': random.uniform(5, 15)
                }
            nutritional_values[k][l] = round(values[l], 4) if isinstance(values[l], float) else values[l]

    # Edge costs (triple nested dict)
    edge_cost = {i: {j: {k: 999999.99 for k in foods} for j in nodes} for i in nodes}
    for i in nodes:
        for j in nodes:
            if i == j or edges[i][j] == 0:
                continue
            for k in foods:
                if i in supplier_nodes and j in transshipment_nodes:
                    base = 0.8
                elif i in transshipment_nodes and j in beneficiary_nodes:
                    base = 1.2
                elif i in transshipment_nodes and j in transshipment_nodes:
                    base = 0.5
                else:
                    base = 1.5
                edge_cost[i][j][k] = round(base + random.uniform(0.2, 0.5), 2)

    # Path costs (nested dict)
    path_cost = {p: {k: 0.0 for k in foods} for p in paths}
    for p in paths:
        path_nodes = p.split('-')
        for k in foods:
            path_cost_value = sum(edge_cost[path_nodes[i]][path_nodes[i+1]][k] for i in range(len(path_nodes)-1))
            commodity_factor = random.uniform(0.9, 1.1)
            path_cost[p][k] = round(path_cost_value * commodity_factor, 2)

    # Path end indicators (nested dict)
    path_end_indicator = {j: {p: int(p.split('-')[-1] == j) for p in paths} for j in beneficiary_nodes}

    # Procurement costs (dict, per food only)
    procurement_cost = {k: 0.0 for k in foods}
    for k in foods:
        food_num = int(k.split('_')[1])
        if food_num % 10 in [1, 2, 9]:
            base = 0.7
        elif food_num % 10 in [3, 0, 8]:
            base = 1.3
        elif food_num % 10 in [4, 5, 6, 7]:
            base = 1.1
        elif food_num % 10 in [5, 3]:
            base = 1.4
        else:
            base = 1.0
        procurement_cost[k] = round(base, 2)

    data = {
        'nutrients': nutrients,
        'foods': foods,
        'beneficiary_nodes': beneficiary_nodes,
        'supplier_nodes': supplier_nodes,
        'transshipment_nodes': transshipment_nodes,
        'all_nodes': nodes,
        'edges': edges,
        'paths': paths,
        'demand': number_of_beneficiaries,
        'nutritional_requirements': nutricial_requirements,
        'nutritional_values': nutritional_values,
        'path_costs': path_cost,
        'path_end_indicators': path_end_indicator,
        'procurement_costs': procurement_cost,
        'edge_costs': edge_cost,
    }

    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Data written to {output_path}")

if __name__ == "__main__":
    generate_data()