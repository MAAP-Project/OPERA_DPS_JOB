#!/usr/bin/env bash
set -euo pipefail

# (optional) conda activation...
# source /opt/conda/etc/profile.d/conda.sh && conda activate subset_mask_cog || true

OUT="${USER_OUTPUT_DIR:-output}"   # DPS wrapper uses 'output' (relative)
mkdir -p "$OUT" /output

python /app/OPERA_DPS_JOB/asf-s1-edc.py

# If Python fell back to /output, collect into $OUT (unless $OUT IS /output)
if [[ "$OUT" != "/output" && -d /output ]]; then
  find /output -maxdepth 1 -type f -name '*.tif' -exec cp -v {} "$OUT"/ \;
fi

echo "[run] collected files:"
ls -lh "$OUT"
