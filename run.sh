#!/usr/bin/env bash
# run.sh — DPS positional-only args -> CLI flags (OPERA water-mask)
set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PY='conda run --live-stream -p /opt/conda/envs/subset_watermask_cog python'

# ---- Directories ------------------------------------------------------------
# Use relative 'output' folder at the job working dir (what reviewers expect).
OUTPUT_DIR="${USER_OUTPUT_DIR:-output}"
export USER_OUTPUT_DIR="${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Helpful debug
echo "PWD=${PWD}"
echo "USER_OUTPUT_DIR=${USER_OUTPUT_DIR}"

# ---- Positional args --------------------------------------------------------
SHORT_NAME="${1:-${SHORT_NAME:-}}"
TEMPORAL="${2:-${TEMPORAL:-}}"
BBOX="${3:-${BBOX:-}}"
LIMIT="${4:-${LIMIT:-}}"
GRANULE_UR="${5:-${GRANULE_UR:-}}"
IDX_WINDOW="${6:-${IDX_WINDOW:-}}"
S3_URL="${7:-${S3_URL:-}}"

# ---- Build CLI args ---------------------------------------------------------
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

# Tell Python where to write outputs (ensure your script supports --output-dir)
ARGS+=("--output-dir" "${USER_OUTPUT_DIR}")

echo "run.sh: launching water-mask export..."
echo "  OUT: ${USER_OUTPUT_DIR}"
echo "  POS: 1=${SHORT_NAME:-} 2=${TEMPORAL:-} 3=${BBOX:-} 4=${LIMIT:-} 5=${GRANULE_UR:-} 6=${IDX_WINDOW:-} 7=${S3_URL:-}"

# ---- Logging for DPS triage -------------------------------------------------
logfile="_opera-watermask.log"   # create in PWD, move later

set -x
${PY} "${basedir}/water_mask_to_cog.py" "${ARGS[@]}" 2>"${logfile}"
# Post-run: show what landed and include DPS stdio logs in the product bundle
ls -l "${USER_OUTPUT_DIR}" || true
cp -v _stderr.txt _stdout.txt "${USER_OUTPUT_DIR}" || true
mv -v "${logfile}" "${USER_OUTPUT_DIR}"
set +x
