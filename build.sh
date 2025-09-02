#!/usr/bin/env bash
# build.sh — set up a lightweight venv with the exact deps your script needs.

set -euo pipefail

# Where to put the virtual environment (inside the repo/image)
VENV_DIR="${VENV_DIR:-/opt/venv}"

# Use system Python to create a venv
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

# Upgrade pip tooling
pip install --no-cache-dir -U pip wheel setuptools

# Core deps:
# - xarray/rioxarray/rasterio: open & COG export
# - s3fs: remote S3 reads via fsspec
# - shapely/pyproj: bbox reprojection & clipping
# - netCDF4/h5netcdf/scipy: multiple backends for OPERA files
# - maap-py: MAAP SDK
pip install --no-cache-dir \
  numpy \
  xarray \
  rioxarray \
  rasterio \
  s3fs \
  shapely \
  pyproj \
  netCDF4 \
  h5netcdf \
  scipy \
  maap-py

# Quick import smoke test (fails fast if anything’s off)
python - <<'PY'
import xarray, rioxarray, rasterio, s3fs, shapely, pyproj, netCDF4, h5netcdf, scipy
from maap.maap import MAAP
print("Deps OK")
PY

echo "build.sh: environment ready at ${VENV_DIR}"
