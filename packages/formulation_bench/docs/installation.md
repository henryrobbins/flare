# Installation

## Install the package

```bash
pip install formulation-bench
```

## Quickstart

```python
from formulation_bench import Dataset

ds = Dataset.load()

# Iterate over problems
for problem in ds.problems:
    print(problem.id, problem.description)

# Access a specific problem and its formulations
p1 = ds.problem("p1")
for f in p1.formulations:
    print(f.id, f.valid)

# Iterate over labelled formulation pairs
for pair in ds.pairs:
    print(pair.a.id, pair.b.id, pair.reformulation)
```

```{note}
The API above is illustrative — see the {doc}`api/index` for the actual
entry points exposed by each module.
```
