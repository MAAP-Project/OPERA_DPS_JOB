#!/usr/bin/env bash
# run.sh — executes water_mask_to_cog.py using venv if present, otherwise conda env, otherwise system python.

set -euo pipefail

basedir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- Runtime selection ----------
PY=""  # will be set below
ENV_NAME="${ENV_NAME:-subset_watermask_cog}"

# Prefer venv if present (matches your current build.sh output)
if [[ -x /opt/venv/bin/python ]]; then
  PY="/opt/venv/bin/python"
else
  # Try conda env if available
  if command -v conda >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    if [[ -f /opt/conda/etc/profile.d/conda.sh ]]; then
      source /opt/conda/etc/profile.d/conda.sh || true
    fi
    if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
      PY="conda:/${ENV_NAME}"
    fi
  fi
fi

# Fallback to system python
if [[ -z "${PY}" ]]; then
  if command -v python >/dev/null 2>&1; then
    PY="$(command -v python)"
  else
    echo "ERROR: No Python runtime found (venv, conda, or system)." >&2
    exit 1
  fi
fi

# ---------- Output dir ----------
export USER_OUTPUT_DIR="${USER_OUTPUT_DIR:-output}"
mkdir -p "${USER_OUTPUT_DIR}"

# ---------- Build CLI args from env ----------
ARGS=()

add_arg() {
  # add_arg FLAG VALUE -> appends "--FLAG=VALUE" only if VALUE is non-empty
  local flag="$1"
  local val="${2:-}"
  if [[ -n "${val}" ]]; then
    ARGS+=("--${flag}=${val}")
  fi
}

add_arg "short-name"          "${SHORT_NAME:-}"
add_arg "temporal"            "${TEMPORAL:-}"
add_arg "bbox"                "${BBOX:-}"           # safe even if starts with '-'
add_arg "limit"               "${LIMIT:-}"
add_arg "granule-ur"          "${GRANULE_UR:-}"
add_arg "tile"                "${TILE:-}"
add_arg "compress"            "${COMPRESS:-}"
add_arg "overview-resampling" "${OVERVIEW_RESAMPLING:-}"
add_arg "out-name"            "${OUT_NAME:-}"
add_arg "idx-window"          "${IDX_WINDOW:-}"
add_arg "s3-url"              "${S3_URL:-}"

# Default short-name if not provided
if ! printf '%s\0' "${ARGS[@]}" | grep -q -- '--short-name='; then
  ARGS+=("--short-name=OPERA_L3_DISP-S1_V1")
fi

echo "run.sh: launching water-mask export..."
echo "run.sh: output dir: ${USER_OUTPUT_DIR}"

# ---------- Execute ----------
if [[ "${PY}" == conda:* ]]; then
  env_name="${PY#conda:/}"
  conda run --live-stream -n "${env_name}" python "${basedir}/water_mask_to_cog.py" "${ARGS[@]}"
else
  exec "${PY}" "${basedir}/water_mask_to_cog.py" "${ARGS[@]}"
fi
