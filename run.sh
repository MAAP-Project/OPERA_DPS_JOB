# !/usr/bin/env bash
set -euo pipefail
echo "[run] starting…"

# Activate env if we created one in build.sh; otherwise fall back to default.
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh || true
  conda activate subset_mask_cog 2>/dev/null || conda activate python 2>/dev/null || true
fi

# Helpful tunables (safe defaults)
export GDAL_CACHEMAX=512
mkdir -p /output

# Run your algorithm (adjust the path if you keep the file elsewhere)
python OPERA_DPS_JOB/disp_subset_mask_to_cog.py

echo "[run] finished."
