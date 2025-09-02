#!/usr/bin/env -S bash -l
set -euo pipefail

# ensure conda available
source /opt/conda/etc/profile.d/conda.sh
conda activate subset_watermask_cog

# Required/optional job params passed by DPS (examples shown)
SHORT_NAME="${SHORT_NAME:-OPERA_L3_DISP-S1_V1}"
TEMPORAL="${TEMPORAL:-}"            # e.g. 2024-01-01T00:00:00Z,2024-01-31T23:59:59Z
BBOX="${BBOX:-}"                    # e.g. -122.8,37.2,-121.7,38.1
IDX_WINDOW="${IDX_WINDOW:-}"        # e.g. 0:2000,0:2000
OUT_NAME="${OUT_NAME:-water_mask_subset.cog.tif}"
LIMIT="${LIMIT:-10}"
GRANULE_UR="${GRANULE_UR:-}"

CMD=(/opt/conda/envs/subset_watermask_cog/bin/python /app/OPERA_DPS_JOB/water_mask_to_cog.py
  --short-name "$SHORT_NAME"
  --limit "$LIMIT"
  --out-name "$OUT_NAME"
)

[[ -n "$TEMPORAL"   ]] && CMD+=(--temporal "$TEMPORAL")
[[ -n "$BBOX"       ]] && CMD+=(--bbox "$BBOX")
[[ -n "$IDX_WINDOW" ]] && CMD+=(--idx-window "$IDX_WINDOW")
[[ -n "$GRANULE_UR" ]] && CMD+=(--granule-ur "$GRANULE_UR")

echo "[run] ${CMD[*]}"
exec "${CMD[@]}"
