# Downloading the dataset

The dataset is published as a `dataset.tar.gz` asset attached to each
tagged release of the {github}`FLARE GitHub repository </releases>`.
There are three common ways to download it.

:::{tip}
You can browse the dataset contents in {doc}`/problems/index` or {github}`GitHub </tree/main/dataset>` without needing to download the dataset.
:::

## Python (recommended)

`formulation-bench` ships a `download_dataset` helper that fetches the
tarball, extracts it in a local cache directory, and
returns the extracted path. Subsequent calls reuse the cached copy.

```python
from formulation_bench import download_dataset

root = download_dataset()                   # latest version this package targets
root = download_dataset("dataset-v0.2.0")   # download a specific release tag
root = download_dataset(force=True)         # re-download, overwriting cache
```

It is often more convenient to use `Dataset.load()`:

```python
from formulation_bench import Dataset

ds = Dataset.load()
```

Cache location, in order of precedence:

1. `cache_dir=` argument to `download_dataset` / `Dataset.load`.
2. `$FORMULATION_BENCH_CACHE` environment variable.
3. `$XDG_CACHE_HOME/formulation_bench` if `$XDG_CACHE_HOME` is set.
4. `~/.cache/formulation_bench`.

## `curl`

If you just want the dataset files on disk, fetch the tarball directly
from the release page:

```bash
VERSION=dataset-v0.2.0
curl -L -o dataset.tar.gz \
    "https://github.com/henryrobbins/flare/releases/download/${VERSION}/dataset.tar.gz"

mkdir -p formulation-bench && tar -xzf dataset.tar.gz -C formulation-bench
```

:::{warning}
The archive expands to a top-level `dataset/` directory, so running
`tar -xzf` in a working directory that already contains `dataset/` will overwrite it. It is recommended to extract it in a fresh directory (like above).
:::

You can now load the dataset with:

```python
from formulation_bench import Dataset

ds = Dataset("formulation-bench/dataset")
```

## GitHub website

1. Open the {github}`FLARE releases page </releases>`.
2. Pick a release (e.g. `dataset-v0.2.0`).
3. Under **Assets**, click `dataset.tar.gz`.
4. Extract it with your archive tool of choice.
