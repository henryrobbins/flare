# Installation

## Install the package

The `formulation-bench` package is available on [PyPI](https://pypi.org/project/formulation-bench/) and can be installed with `pip`:

```bash
pip install formulation-bench
```

## Quickstart

Download the dataset:

```python
from formulation_bench import Dataset
ds = Dataset.load()
```

Access a problem's formulations:

```python
p1 = ds.problems[1]
p1a = p1.formulations["a"]
```

Access reformulation pairs:

```python
pos = [r for r in ds.reformulations if r.is_reformulation]
neg = [r for r in ds.reformulations if not r.is_reformulation]
```

See {doc}`user_guide/index` for user guides and {doc}`api/index` for the full API reference.
