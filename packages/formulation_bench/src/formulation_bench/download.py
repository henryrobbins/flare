from __future__ import annotations

import hashlib
import os
import tarfile
import urllib.request
from pathlib import Path

#: GitHub repo containing the dataset releases.
REPO = "henryrobbins/flare"

#: Name of the dataset tarball asset in the releases.
ASSET_NAME = "dataset.tar.gz"

#: The snapshot version of the dataset this package was built against.
#: The package is compatible with all dataset versions sharing the same major version.
DEFAULT_DATASET_VERSION = "dataset-v0.2.0"


def _default_cache_dir() -> Path:
    base = os.environ.get("FORMULATION_BENCH_CACHE")
    if base:
        return Path(base)
    xdg = os.environ.get("XDG_CACHE_HOME")
    root = Path(xdg) if xdg else Path.home() / ".cache"
    return root / "formulation_bench"


def _release_url(version: str) -> str:
    return f"https://github.com/{REPO}/releases/download/{version}/{ASSET_NAME}"


def download_dataset(
    version: str | None = None,
    cache_dir: str | Path | None = None,
    force: bool = False,
    sha256: str | None = None,
) -> Path:
    """Download the FormulationBench dataset.

    A tarball is fetched from the GitHub release tagged ``version`` and
    extracted under ``<cache_dir>/<version>/``. Subsequent calls with the same
    ``version`` reuse the cached copy unless ``force=True``.

    Parameters
    ----------
    version : str, optional
        Release tag, e.g. ``"dataset-v0.2.0"``. Defaults to
        :data:`DEFAULT_DATASET_VERSION`, the snapshot version this package was built
        against.
    cache_dir : str or pathlib.Path, optional
        Cache root. Defaults to ``$FORMULATION_BENCH_CACHE`` or
        ``$XDG_CACHE_HOME/formulation_bench`` (``~/.cache/formulation_bench``).
    force : bool, default False
        Re-download and overwrite the cached copy.

    Returns
    -------
    root : pathlib.Path
        Path to the extracted dataset root. Load the dataset with ``Dataset(root)``.

    Examples
    --------

    Download the default version of the dataset (or load from cache)::

        >>> from formulation_bench import download_dataset
        >>> path = download_dataset()
        >>> path
        PosixPath('.../.cache/formulation_bench/dataset-v0.2.0/dataset')
        >>> from formulation_bench import Dataset
        >>> ds = Dataset(path)
        >>> sorted(ds.problems)[:5]
        [1, 2, 3, 4, 5]

    Reload the dataset from cache::

        >>> path = download_dataset()
        >>> path
        PosixPath('.../.cache/formulation_bench/dataset-v0.2.0/dataset')

    Force re-download and overwrite the cached copy::

        >>> path = download_dataset(force=True)
        >>> path
        PosixPath('.../.cache/formulation_bench/dataset-v0.2.0/dataset')

    Provide a custom cache directory::

        >>> path = download_dataset(cache_dir="./custom_cache")
        >>> path
        PosixPath('custom_cache/dataset-v0.2.0/dataset')
    """
    version = version or DEFAULT_DATASET_VERSION
    cache_root = Path(cache_dir) if cache_dir else _default_cache_dir()
    version_dir = cache_root / version
    extracted = version_dir / "dataset"
    if extracted.exists() and not force:
        return extracted

    version_dir.mkdir(parents=True, exist_ok=True)
    archive = version_dir / ASSET_NAME
    url = _release_url(version)
    urllib.request.urlretrieve(url, archive)  # noqa: S310

    if sha256:
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if digest != sha256:
            archive.unlink(missing_ok=True)
            raise ValueError(
                f"sha256 mismatch for {url}: expected {sha256}, got {digest}"
            )

    with tarfile.open(archive, "r:gz") as tf:
        tf.extractall(version_dir, filter="data")
    archive.unlink(missing_ok=True)

    if not extracted.exists():
        raise RuntimeError(
            f"expected {extracted} after extracting {url}; "
            "tarball layout may be wrong (top-level dir must be 'dataset/')"
        )
    return extracted
