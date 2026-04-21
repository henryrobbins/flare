import numpy as np
import random
import json

def generate_data(seed=42, output_path='src/datasets/open_pit_mining/large_data.json'):
    np.random.seed(seed)
    random.seed(seed)
    # Problem size parameters
    NUM_BLOCKS = 500  # Number of blocks (large dataset)
    NUM_PERIODS = 20  # Number of periods (large dataset)
    blocks = list(range(1, NUM_BLOCKS + 1))  # 1-based indices
    periods = list(range(1, NUM_PERIODS + 1)) 

    # Assign grades randomly (float in [0.5, 3.0])
    grade = {i: float(np.round(np.random.uniform(0.5, 3.0), 2)) for i in blocks}
    blocks_grade_1 = [i for i in blocks if np.isclose(grade[i], 1.0)]
    blocks_grade_less_1 = [i for i in blocks if grade[i] < 1.0]

    # Ore and waste tonnage
    ore_tonnage = {i: float(np.random.randint(1000, 5000)) for i in blocks}
    waste_tonnage = {i: float(np.random.randint(500, 3000)) for i in blocks}

    # NPV for each block and period
    npv = {}
    for i in blocks:
        npv[i] = {}
        base_value = (grade[i] * ore_tonnage[i] * 50.0) - (ore_tonnage[i] + waste_tonnage[i]) * 10.0
        for t in periods:
            discount = 1.0 / ((1.08) ** (t-1))
            noise = np.random.uniform(0.85, 1.15)
            npv[i][t] = float(np.round(base_value * discount * noise, 2))

    # Precedence matrix: precedence[i][j] = 1 if i must be mined before j
    precedence = {i: {j: 0 for j in blocks} for i in blocks}
    for j in blocks:
        possible_predecessors = [i for i in blocks if i < j]
        num_predecessors = np.random.randint(0, min(4, len(possible_predecessors)+1))
        preds = random.sample(possible_predecessors, num_predecessors) if num_predecessors > 0 else []
        for i in preds:
            precedence[i][j] = 1

    # Global parameters
    grade_min = float(np.round(np.random.uniform(0.7, 1.0), 2))
    grade_max = float(np.round(np.random.uniform(2.0, 2.5), 2))
    processing_capacity_min = float(np.round(0.7 * sum(ore_tonnage[i] for i in blocks) / NUM_PERIODS, 0))
    processing_capacity_max = float(np.round(1.2 * sum(ore_tonnage[i] for i in blocks) / NUM_PERIODS, 0))
    mining_capacity_min = float(np.round(0.7 * sum(ore_tonnage[i] + waste_tonnage[i] for i in blocks) / NUM_PERIODS, 0))
    mining_capacity_max = float(np.round(1.2 * sum(ore_tonnage[i] + waste_tonnage[i] for i in blocks) / NUM_PERIODS, 0))

    data = {
        'blocks': blocks,
        'blocks_grade_1': blocks_grade_1,
        'blocks_grade_less_1': blocks_grade_less_1,
        'periods': periods,
        'npv': npv,
        'grade': grade,
        'ore_tonnage': ore_tonnage,
        'waste_tonnage': waste_tonnage,
        'grade_min': grade_min,
        'grade_max': grade_max,
        'processing_capacity_min': processing_capacity_min,
        'processing_capacity_max': processing_capacity_max,
        'mining_capacity_min': mining_capacity_min,
        'mining_capacity_max': mining_capacity_max,
        'precedence': precedence
    }


    if output_path is not None:
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Data written to {output_path}")


if __name__ == "__main__":
    generate_data()