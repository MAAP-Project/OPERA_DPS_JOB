#!/usr/bin/env bash
set -euo pipefail

basedir="$( cd "$(dirname "$0")" ; pwd -P )"
VENV="${basedir}/.venv"

# Create venv if missing
[ -x "${VENV}/bin/python" ] || python -m venv "${VENV}"

# Upgrade tooling
"${VENV}/bin/python" -m pip install --upgrade pip setuptools wheel

# Install deps (prefer wheels)
# Note: replace 'dask-core' -> 'dask'
"${VENV}/bin/pip" install \
  "numpy>=1.26" \
  "xarray>=2024.6" \
  dask \
  "h5py>=3.10" \
  "netcdf4>=1.6.5" \
  "h5netcdf>=1.3" \
  "rasterio>=1.3.10" \
  "rioxarray>=0.15.5" \
  affine \
  shapely \
  pyproj \
  fsspec s3fs boto3 tqdm maap-py

# Optional sanity check
"${VENV}/bin/python" - <<'PY'
import xarray, rasterio, sys
print("OK:", sys.version.split()[0], "xarray", xarray.__version__, "rasterio", rasterio.__version__)
PY

echo "[build] done."
