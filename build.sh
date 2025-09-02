#!/usr/bin/env bash
set -euo pipefail

echo "[build] start"

# require conda
if ! command -v conda >/dev/null 2>&1; then
  echo "[build] conda not found — please use the MAAP ADE base image."
  exit 2
fi

# strict channel priority helps reproducibility
conda config --system --set channel_priority strict || true

# activate conda in non-interactive shell
# shellcheck disable=SC1091
source /opt/conda/etc/profile.d/conda.sh || true

# resolve repo dir and env.yml path relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_YML="${SCRIPT_DIR}/env.yml"
ENV_NAME="subset_watermask_cog"

# clean old env (ok if it doesn't exist)
conda env remove -n "${ENV_NAME}" -y || true

echo "[build] creating conda env '${ENV_NAME}' from ${ENV_YML}"
conda env create -n "${ENV_NAME}" -f "${ENV_YML}"

echo "[build] smoke test imports..."
conda run -n "${ENV_NAME}" python - <<'PY'
import xarray, rioxarray, rasterio, numpy, pyproj, shapely, s3fs, fsspec, h5netcdf, h5py, maap
print("[build] imports OK")
PY

echo "[build] done"
