# Downloading the dataset

The dataset is published as a `dataset.tar.gz` asset attached to each
tagged release of the [FLARE GitHub repository](https://github.com/henryrobbins/flare/releases).
There are three common ways to grab it.

## Option 1 — Python utility (recommended)

`formulation_bench` ships a `download_dataset` helper that fetches the
tarball, verifies it, extracts it under a local cache directory, and
returns the extracted path. Subsequent calls reuse the cached copy.

```python
from formulation_bench import download_dataset

root = download_dataset()                     # latest version this package targets
root = download_dataset("dataset-v0.1")       # pin to a specific release tag
```

In most cases you don't need to call this directly — `Dataset.load()`
wraps it:

```python
from formulation_bench import Dataset

ds = Dataset.load()                           # downloads on first call, then cached
ds = Dataset.load("dataset-v0.1", force=True) # re-download, overwriting cache
```

Cache location, in order of precedence:

1. `cache_dir=` argument to `download_dataset` / `Dataset.load`.
2. `$FORMULATION_BENCH_CACHE` environment variable.
3. `$XDG_CACHE_HOME/formulation_bench` if set, otherwise
   `~/.cache/formulation_bench`.

To verify the tarball's integrity, pass an expected digest:

```python
download_dataset("dataset-v0.1", sha256="<expected hex digest>")
```

A mismatch deletes the partial download and raises `ValueError`.

## Option 2 — `curl`

If you just want the dataset files on disk, fetch the tarball directly
from the release page:

```bash
VERSION=dataset-v0.1
curl -L -o dataset.tar.gz \
    "https://github.com/henryrobbins/flare/releases/download/${VERSION}/dataset.tar.gz"

tar -xzf dataset.tar.gz
# Produces a top-level `dataset/` directory.
```

To use this with `formulation_bench`, point `Dataset` at the
extracted root:

```python
from formulation_bench import Dataset

ds = Dataset("path/to/dataset")
```

## Option 3 — GitHub website

For one-off browsing or sharing:

1. Open the [FLARE releases page](https://github.com/henryrobbins/flare/releases).
2. Pick a release (e.g. `dataset-v0.1`).
3. Under **Assets**, click `dataset.tar.gz`.
4. Extract it with your archive tool of choice. The archive expands
   to a single `dataset/` directory containing `dataset.json`,
   `problems/`, and `reformulations/`.

You can also browse the dataset directly on GitHub by navigating to
the `dataset/` subtree of any tagged commit — useful for linking to a
specific formulation in an issue or paper.
