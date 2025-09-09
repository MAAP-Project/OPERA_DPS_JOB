#!/usr/bin/env bash
# run.sh — DPS positional-only args -> CLI flags

set -euo pipefail
basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY='conda run --live-stream -p /opt/conda/envs/subset_watermask_cog python'

# Positional args from DPS (current behavior)
# 1 SHORT_NAME, 2 TEMPORAL, 3 BBOX, 4 LIMIT, 5 GRANULE_UR, 6 IDX_WINDOW, 7 S3_URL
SHORT_NAME="${1:-${SHORT_NAME:-}}"
TEMPORAL="${2:-${TEMPORAL:-}}"
BBOX="${3:-${BBOX:-}}"
LIMIT="${4:-${LIMIT:-}}"
GRANULE_UR="${5:-${GRANULE_UR:-}}"
IDX_WINDOW="${6:-${IDX_WINDOW:-}}"
S3_URL="${7:-${S3_URL:-}}"

export USER_OUTPUT_DIR="${USER_OUTPUT_DIR:-output}"
mkdir -p "$USER_OUTPUT_DIR"

# Build CLI args
ARGS=()
[[ -n "${SHORT_NAME}" ]] && ARGS+=("--short-name" "${SHORT_NAME}")
[[ -n "${TEMPORAL}"   ]] && ARGS+=("--temporal" "${TEMPORAL}")
[[ -n "${BBOX}"       ]] && ARGS+=("--bbox" "${BBOX}")
[[ -n "${LIMIT}"      ]] && ARGS+=("--limit" "${LIMIT}")
[[ -n "${GRANULE_UR}" ]] && ARGS+=("--granule-ur" "${GRANULE_UR}")
[[ -n "${IDX_WINDOW}" ]] && ARGS+=("--idx-window" "${IDX_WINDOW}")
[[ -n "${S3_URL}"     ]] && ARGS+=("--s3-url" "${S3_URL}")

# Default short name if missing
if ! printf '%s\0' "${ARGS[@]}" | grep -q -- '--short-name'; then
  ARGS+=("--short-name" "OPERA_L3_DISP-S1_V1")
fi

echo "run.sh: launching water-mask export..."
echo "  OUT: ${USER_OUTPUT_DIR}"
echo "  POS: 1=${SHORT_NAME:-} 2=${TEMPORAL:-} 3=${BBOX:-} 4=${LIMIT:-} 5=${GRANULE_UR:-} 6=${IDX_WINDOW:-} 7=${S3_URL:-}"

exec $PY "${basedir}/water_mask_to_cog.py" "${ARGS[@]}"
