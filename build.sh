# !/bin/bash
set -euo pipefail

# Install runtime deps for the job image
pip install --no-cache-dir \
  boto3 \
  numpy \
  xarray \
  rioxarray \
  rasterio \
  shapely \
  pyproj \
  affine \
  h5netcdf \
  maap-py
