#!/usr/bin/env bash
set -euo pipefail

echo "[build] start"

# Require conda (present in MAAP base image)
if ! command -v conda >/dev/null 2>&1; then
  echo "[build] conda not found — please use the MAAP ADE base image."
  exit 2
fi

# Prefer reproducible solves
conda config --system --set channel_priority strict || true

# Activate conda in this non-interactive shell
# shellcheck disable=SC1091
source /opt/conda/etc/profile.d/conda.sh || true

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_YML="${SCRIPT_DIR}/env.yml"
ENV_NAME="subset_watermask_cog"

# Clean any old env (ok if missing)
conda env remove -n "${ENV_NAME}" -y || true

echo "[build] creating conda env '${ENV_NAME}' from ${ENV_YML}"
conda env create -n "${ENV_NAME}" -f "${ENV_YML}"

echo "[build] smoke test imports..."
conda run -n "${ENV_NAME}" python - <<'PY'
import numpy, rasterio, rioxarray, xarray, pyproj, shapely, s3fs, fsspec, h5netcdf, h5py
print("[build] imports OK from", __import__("sys").executable)
PY

echo "[build] done"
