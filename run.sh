#!/usr/bin/env bash
set -euo pipefail
basedir="$( cd "$(dirname "$0")" ; pwd -P )"
VENV="${basedir}/.venv"
OUT="/output"
mkdir -p "${OUT}"

# Build venv if missing
if [ ! -x "${VENV}/bin/python" ]; then
  bash "${basedir}/build.sh"
fi

# --- Make sure GDAL/PROJ can find their data ---
# PROJ path from pyproj
PROJ_DIR="$("${VENV}/bin/python" - <<'PY'
import pyproj
print(pyproj.datadir.get_data_dir())
PY
)"
export PROJ_LIB="${PROJ_DIR}"
export PROJ_DATA="${PROJ_DIR}"
# let network fallback work if needed
export PROJ_NETWORK=ON

# GDAL data path from rasterio
GDAL_DIR="$("${VENV}/bin/python" - <<'PY'
import rasterio
from rasterio._env import get_gdal_data
print(get_gdal_data() or "")
PY
)"
if [ -n "${GDAL_DIR}" ]; then
  export GDAL_DATA="${GDAL_DIR}"
fi

# Optional: more stable CPL config for cloud reads
export VSI_CACHE=TRUE
export CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif,.tiff,.img,.vrt,.nc,.zarr"

# --- Run the job ---
exec "${VENV}/bin/python" "${basedir}/asf-s1-edc.py" --dest "${OUT}"
