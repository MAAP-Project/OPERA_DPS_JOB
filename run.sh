#!/usr/bin/env bash
# run.sh — executes water_mask_to_cog.py; supports positional inputs AND env vars.

set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Positional inputs (override envs if provided) ----------
# Order:
#  1=SHORT_NAME   2=TEMPORAL   3=BBOX   4=LIMIT   5=GRANULE_UR   6=IDX_WINDOW   7=S3_URL
if [[ $# -ge 1 && -n "${1:-}" ]]; then SHORT_NAME="$1"; fi
if [[ $# -ge 2 && -n "${2:-}" ]]; then TEMPORAL="$2"; fi
if [[ $# -ge 3 && -n "${3:-}" ]]; then BBOX="$3"; fi
if [[ $# -ge 4 && -n "${4:-}" ]]; then LIMIT="$4"; fi
if [[ $# -ge 5 && -n "${5:-}" ]]; then GRANULE_UR="$5"; fi
if [[ $# -ge 6 && -n "${6:-}" ]]; then IDX_WINDOW="$6"; fi
if [[ $# -ge 7 && -n "${7:-}" ]]; then S3_URL="$7"; fi

# ---------- Output dir ----------
export USER_OUTPUT_DIR="${USER_OUTPUT_DIR:-output}"
mkdir -p "${USER_OUTPUT_DIR}"

# ---------- Build CLI args ----------
ARGS=()
add_arg() {
  # add_arg FLAG VALUE -> appends "--FLAG=VALUE" only if VALUE is non-empty
  local flag="$1"; local val="${2:-}"
  [[ -n "$val" ]] && ARGS+=("--${flag}=${val}")
}

add_arg "short-name"          "${SHORT_NAME:-}"
add_arg "temporal"            "${TEMPORAL:-}"
add_arg "bbox"                "${BBOX:-}"
add_arg "limit"               "${LIMIT:-}"
add_arg "granule-ur"          "${GRANULE_UR:-}"
add_arg "tile"                "${TILE:-}"
add_arg "compress"            "${COMPRESS:-}"
add_arg "overview-resampling" "${OVERVIEW_RESAMPLING:-}"
add_arg "out-name"            "${OUT_NAME:-}"
add_arg "idx-window"          "${IDX_WINDOW:-}"
add_arg "s3-url"              "${S3_URL:-}"

# Default short-name if none supplied
if ! printf '%s\0' "${ARGS[@]}" | grep -q -- '--short-name='; then
  ARGS+=("--short-name=OPERA_L3_DISP-S1_V1")
fi

echo "run.sh: launching water-mask export..."
echo "run.sh: output dir: ${USER_OUTPUT_DIR}"

# Prefer venv Python if present; else system python
PY="/opt/venv/bin/python"
if [[ ! -x "$PY" ]]; then
  PY="$(command -v python)"
fi
exec "${PY}" "${basedir}/water_mask_to_cog.py" "${ARGS[@]}"
