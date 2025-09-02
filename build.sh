#!/usr/bin/env bash
set -euo pipefail

echo "[build] start"

# Ensure conda is sourced
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  source /opt/conda/etc/profile.d/conda.sh
else
  echo "[build] conda.sh not found"; exit 2
fi

ENV_NAME="subset_watermask_cog"
ENV_YML="/app/OPERA_DPS_JOB/env.yml"

# Remove any old env (ok if none exists)
conda env remove -n "${ENV_NAME}" -y || true

echo "[build] creating env from ${ENV_YML}"
# Force classic solver to avoid libmamba issues
CONDA_SOLVER=classic CONDA_NO_PLUGINS=true conda env create -n "${ENV_NAME}" -f "${ENV_YML}"

echo "[build] smoke test"
conda run -n "${ENV_NAME}" python - <<'PY'
import numpy, xarray, rioxarray, rasterio, pyproj, shapely, s3fs, fsspec, h5py, boto3, netCDF4, scipy
import maap
print("[build] imports OK")
PY

echo "[build] done"
