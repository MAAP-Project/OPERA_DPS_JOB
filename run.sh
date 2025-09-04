#!/usr/bin/env bash
# run.sh — executes your script with env-var-driven arguments inside the venv.

set -euo pipefail

# Paths
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${VENV_DIR:-/opt/venv}"
PY="${VENV_DIR}/bin/python"

# Ensure venv is present
if [[ ! -x "$PY" ]]; then
  echo "run.sh: ${PY} not found. Did you run ./build.sh?" >&2
  exit 1
fi

# Required by your script (DPS usually sets this; default for local runs)
export USER_OUTPUT_DIR="${USER_OUTPUT_DIR:-/output}"
mkdir -p "$USER_OUTPUT_DIR"

# Map environment variables to CLI flags (only pass if set)
# Available envs (all optional):
#   SHORT_NAME (default OPERA_L3_DISP-S1_V1)
#   TEMPORAL   e.g.  "2023-01-01T00:00:00Z,2023-12-31T23:59:59Z"
#   BBOX       e.g.  "minx,miny,maxx,maxy" in WGS84
#   LIMIT      e.g.  "5"
#   GRANULE_UR exact GranuleUR to force a specific file
#   TILE       e.g.  "256"
#   COMPRESS   e.g.  "DEFLATE", "LZW", "ZSTD"
#   OVERVIEW_RESAMPLING e.g. "nearest"
#   OUT_NAME   e.g.  "water_mask_subset.cog.tif"
#   IDX_WINDOW e.g.  "y0:y1,x0:x1" (overrides BBOX if provided)

ARGS=()
[[ -n "${SHORT_NAME:-}" ]]            && ARGS+=("--short-name" "${SHORT_NAME}")
[[ -n "${TEMPORAL:-}" ]]              && ARGS+=("--temporal" "${TEMPORAL}")
[[ -n "${BBOX:-}" ]]                  && ARGS+=("--bbox" "${BBOX}")
[[ -n "${LIMIT:-}" ]]                 && ARGS+=("--limit" "${LIMIT}")
[[ -n "${GRANULE_UR:-}" ]]            && ARGS+=("--granule-ur" "${GRANULE_UR}")
[[ -n "${TILE:-}" ]]                  && ARGS+=("--tile" "${TILE}")
[[ -n "${COMPRESS:-}" ]]              && ARGS+=("--compress" "${COMPRESS}")
[[ -n "${OVERVIEW_RESAMPLING:-}" ]]   && ARGS+=("--overview-resampling" "${OVERVIEW_RESAMPLING}")
[[ -n "${OUT_NAME:-}" ]]              && ARGS+=("--out-name" "${OUT_NAME}")
[[ -n "${IDX_WINDOW:-}" ]]            && ARGS+=("--idx-window" "${IDX_WINDOW}")

# Defaults (match your script’s defaults if envs not set)
if ! printf '%s\0' "${ARGS[@]}" | grep -q -- '--short-name'; then
  ARGS+=("--short-name" "OPERA_L3_DISP-S1_V1")
fi

echo "run.sh: launching water-mask export..."
echo "run.sh: output dir: ${USER_OUTPUT_DIR}"

exec "$PY" "${HERE}/water_mask_to_cog.py" "${ARGS[@]}"
