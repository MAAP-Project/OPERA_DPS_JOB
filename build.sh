#!/usr/bin/env bash
set -euo pipefail

echo "[build] starting…"

# If conda exists and you want to use it, activate it.
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh || true
fi

ENV_NAME="subset_mask_cog"

# Use env.yml if present (your repo shows env.yml)
if [[ -f env.yml ]] && command -v conda >/dev/null 2>&1; then
  echo "[build] creating conda env '${ENV_NAME}' from env.yml"
  conda env remove -n "${ENV_NAME}" -y || true
  conda env create -n "${ENV_NAME}" -f env.yml
else
  echo "[build] no conda env file or conda missing — using current Python env and ensuring deps"
  python -m pip install --upgrade pip
  pip install --no-cache-dir --upgrade \
    numpy xarray rioxarray rasterio shapely pyproj h5netcdf boto3 affine maap-py
fi

# Smoke test (no heredoc, avoids CRLF/heredoc issues)
python -c "import numpy, xarray, rioxarray, rasterio, shapely, pyproj, h5netcdf, boto3, affine; print('[build] imports OK')"

echo "[build] done."
