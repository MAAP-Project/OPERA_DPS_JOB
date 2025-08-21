# !/bin/bash
set -euo pipefail

# Sanity prints (show the exact Python we’ll use)
python -V
python -m pip --version

# Keep tooling current
python -m pip install --upgrade --no-cache-dir pip setuptools wheel

# Runtime deps
python -m pip install --no-cache-dir \
  numpy \
  boto3 \
  xarray \
  rioxarray \
  rasterio \
  shapely \
  pyproj \
  affine \
  h5netcdf \
  maap-py
