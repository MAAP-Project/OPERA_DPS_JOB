# !/usr/bin/env bash
set -euo pipefail
basedir="$( cd "$(dirname "$0")" ; pwd -P )"
VENV="${basedir}/.venv"
OUT="/output"
mkdir -p "${OUT}"

# Safety: if venv missing, build it
if [ ! -x "${VENV}/bin/python" ]; then
  bash "${basedir}/build.sh"
fi

"${VENV}/bin/python" "${basedir}/asf-s1-edc.py" --dest "${OUT}"
echo "[run] done."
