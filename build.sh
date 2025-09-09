#!/usr/bin/env bash
set -euo pipefail

ENV_PREFIX="/opt/conda/envs/subset_watermask_cog"

conda env create -f environment.yml --prefix "$ENV_PREFIX"
conda clean -afy

# Sanity check
conda run -p "$ENV_PREFIX" python - <<'PY'
import xarray, rioxarray, rasterio, s3fs, shapely, pyproj, netCDF4, h5netcdf, scipy, requests
from maap.maap import MAAP
print("Conda env OK")
PY

echo "Built conda env at $ENV_PREFIX"
