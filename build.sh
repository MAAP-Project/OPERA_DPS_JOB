#!/usr/bin/env bash
set -euo pipefail

echo "[build] starting…"

# If conda is available, prefer creating/using a clean env from an environment.yml (optional).
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh || true
fi

ENV_NAME="subset_mask_cog"

if [[ -f environment.yml ]] && command -v conda >/dev/null 2>&1; then
  echo "[build] creating conda env '${ENV_NAME}' from environment.yml"
  conda env remove -n "${ENV_NAME}" -y || true
  conda env create -n "${ENV_NAME}" -f environment.yml
else
  echo "[build] no environment.yml or no conda — using current Python env; ensuring deps exist"
  python -m pip install --upgrade pip
  pip install --no-cache-dir --upgrade \
    numpy xarray rioxarray rasterio shapely pyproj h5netcdf boto3
fi

# Quick smoke test that key libs import
python - <<'PY'
pip install --no-cache-dir --upgrade \
   numpy xarray rioxarray rasterio shapely pyproj h5netcdf boto3 affine maap-py

print("[build] imports OK")
PY

echo "[build] done."
