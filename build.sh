# !/bin/bash
set -euo pipefail

# Always install into the same interpreter that will run the job
python -V
python -m pip --version

# Keep tooling current, avoids resolver oddities
python -m pip install --upgrade --no-cache-dir pip setuptools wheel

# Core deps (versions broad enough to work well on MAAP)
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
