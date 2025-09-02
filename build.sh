#!/usr/bin/env -S bash -l
set -euo pipefail

echo "[build] start"

# conda init already done in base; source for non-interactive
source /opt/conda/etc/profile.d/conda.sh

ENV_NAME="subset_watermask_cog"
ENV_YML="/app/OPERA_DPS_JOB/env.yml"

# clean & create
conda env remove -n "$ENV_NAME" -y || true
echo "[build] creating conda env '$ENV_NAME' from $ENV_YML"
CONDA_NO_PLUGINS=true conda env create -n "$ENV_NAME" -f "$ENV_YML"

echo "[build] smoke test imports..."
conda run -n "$ENV_NAME" python - <<'PY'
import xarray, rioxarray, rasterio, numpy, pyproj, shapely, s3fs, h5netcdf, netCDF4, maap
print("[build] imports OK")
PY

echo "[build] done"
