#!/usr/bin/env bash
set -euo pipefail

# (optional) activate your env if you created one in build.sh
if command -v conda >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh || true
  conda activate subset_mask_cog 2>/dev/null || true
fi

mkdir -p /output
python /app/OPERA_DPS_JOB/asf-s1-edc.py
