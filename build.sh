# !/usr/bin/env bash
set -euo pipefail

basedir="$( cd "$(dirname "$0")" ; pwd -P )"
VENV="${basedir}/.venv"

# Create venv if missing
if [ ! -x "${VENV}/bin/python" ]; then
  python -m venv "${VENV}"
fi

# Upgrade tooling
"${VENV}/bin/python" -m pip install --upgrade pip setuptools wheel

# Install deps (prefer wheels for speed)
# Notes:
# - Keep rasterio >=1.3 so we get modern GDAL wheels.
# - maap-py is the package providing `from maap.maap import MAAP`.
# - pin reasonably to avoid solver chaos, but not overly strict.
"${VENV}/bin/pip" install \
  "numpy>=1.26" \
  "xarray>=2024.6" \
  "dask" \
  "h5py>=3.10" \
  "netcdf4>=1.6.5" \
  "h5netcdf>=1.3" \
  "rasterio>=1.3.10" \
  "rioxarray>=0.15.5" \
  "affine" \
  "shapely" \
  "pyproj" \
  "tqdm" \
  "boto3" \
  "fsspec" "s3fs" \
  "maap-py"

# Optional sanity check
"${VENV}/bin/python" - <<'PY'
import sys, xarray as xr, rasterio, numpy as np
print("OK:", sys.version.split()[0], "xarray", xr.__version__, "rasterio", rasterio.__version__)
PY
