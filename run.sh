##!/usr/bin/env bash
set -euo pipefail
echo "[run] starting…"

# (optional) activate env if you made one in build.sh
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh || true
  conda activate subset_mask_cog 2>/dev/null || true
fi

# Resolve the directory this script lives in (it’s under /app/OPERA_DPS_JOB)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/disp_subset_mask_to_cog.py"

# Debug prints (handy once; remove later)
echo "[run] pwd=$(pwd)"
echo "[run] listing ${SCRIPT_DIR}"
ls -lah "${SCRIPT_DIR}"

python "${SCRIPT}"

echo "[run] done."
