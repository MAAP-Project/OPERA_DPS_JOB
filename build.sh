#!/usr/bin/env bash
set -euo pipefail

echo "[build] start"

# Require conda + env.yml for deterministic builds
if ! command -v conda >/dev/null 2>&1; then
  echo "[build] conda not found — please use the MAAP ADE base image."
  exit 2
fi

# shellcheck disable=SC1091
source /opt/conda/etc/profile.d/conda.sh || true
conda env remove -n subset_watermask_cog -y || true
echo "[build] creating env from env.yml"
conda env create -n subset_watermask_cog -f env.yml

conda run -n subset_watermask_cog python - <<'PY'
import xarray, rioxarray, rasterio, numpy, pyproj, shapely, s3fs, fsspec, h5netcdf, h5py, maap
print("[build] imports OK")
PY


echo "[build] done"
