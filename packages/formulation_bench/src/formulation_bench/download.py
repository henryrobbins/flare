"""Download and cache released FormulationBench dataset tarballs."""

from __future__ import annotations

import hashlib
import os
import tarfile
import urllib.request
from pathlib import Path

REPO = "henryrobbins/flare"
ASSET_NAME = "dataset.tar.gz"

#: Dataset release tag that this version of the package is built against.
#: Bumped when the package's defaults move to a newer dataset snapshot.
DEFAULT_DATASET_VERSION = "dataset-v0.1"


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
    *,
    force: bool = False,
    sha256: str | None = None,
) -> Path:
    """Download a released dataset tarball and return the extracted root.

    The tarball is fetched from the GitHub release tagged ``version`` and
    extracted under ``<cache_dir>/<version>/``. Subsequent calls with the same
    ``version`` reuse the cached copy unless ``force=True``.

    Parameters
    ----------
    version : str, optional
        Release tag, e.g. ``"dataset-v0.1"``. Defaults to
        :data:`DEFAULT_DATASET_VERSION`, the snapshot this package was built
        against.
    cache_dir : str or pathlib.Path, optional
        Cache root. Defaults to ``$FORMULATION_BENCH_CACHE`` or
        ``$XDG_CACHE_HOME/formulation_bench`` (``~/.cache/formulation_bench``).
    force : bool, default False
        Re-download and overwrite the cached copy.
    sha256 : str, optional
        If given, verify the tarball's SHA-256 before extraction.

    Returns
    -------
    pathlib.Path
        Path to the extracted dataset root (containing ``dataset.json``).
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
