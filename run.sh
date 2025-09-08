#!/usr/bin/env bash
# run.sh — executes your script with positional args mapped to env vars

set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="/opt/venv/bin/python"

# Map positional args to env vars (DPS passes them this way)
SHORT_NAME="${1:-${SHORT_NAME:-}}"
TEMPORAL="${2:-${TEMPORAL:-}}"
BBOX="${3:-${BBOX:-}}"
LIMIT="${4:-${LIMIT:-}}"
GRANULE_UR="${5:-${GRANULE_UR:-}}"
IDX_WINDOW="${6:-${IDX_WINDOW:-}}"
S3_URL="${7:-${S3_URL:-}}"

export USER_OUTPUT_DIR="${USER_OUTPUT_DIR:-output}"
mkdir -p "$USER_OUTPUT_DIR"

ARGS=()
[[ -n "${SHORT_NAME}" ]]      && ARGS+=("--short-name" "${SHORT_NAME}")
[[ -n "${TEMPORAL}" ]]        && ARGS+=("--temporal" "${TEMPORAL}")
[[ -n "${BBOX}" ]]            && ARGS+=("--bbox" "${BBOX}")
[[ -n "${LIMIT}" ]]           && ARGS+=("--limit" "${LIMIT}")
[[ -n "${GRANULE_UR}" ]]      && ARGS+=("--granule-ur" "${GRANULE_UR}")
[[ -n "${IDX_WINDOW}" ]]      && ARGS+=("--idx-window" "${IDX_WINDOW}")
[[ -n "${S3_URL}" ]]          && ARGS+=("--s3-url" "${S3_URL}")

if ! printf '%s\0' "${ARGS[@]}" | grep -q -- '--short-name'; then
  ARGS+=("--short-name" "OPERA_L3_DISP-S1_V1")
fi

echo "run.sh: launching water-mask export..."
echo "run.sh: output dir: ${USER_OUTPUT_DIR}"

exec "$PY" "${basedir}/water_mask_to_cog.py" "${ARGS[@]}"
