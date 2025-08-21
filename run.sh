# !/bin/bash
set -euo pipefail

# Run from this repo directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[run] CWD: $(pwd)"
echo "[run] python: $(python -V)"
which python
which pip
python - <<'PY'
import sys
print("[run] sys.executable:", sys.executable)
PY

# DPS collects ABSOLUTE /output
export USER_OUTPUT_DIR=/output
mkdir -p "$USER_OUTPUT_DIR"

# Avoid 'Cannot find proj.db' warnings
export PROJ_LIB="/opt/conda/envs/python/share/proj"
[ -d "$PROJ_LIB" ] || export PROJ_LIB="/opt/conda/share/proj"

# Sanity check
test -f asf-s1-edc.py || { echo "[run] ERROR: asf-s1-edc.py not found"; exit 1; }

echo "[run] starting OPERA DPS job..."
# Capture logs AND keep them as artifacts
python asf-s1-edc.py > _stdout.txt 2> _stderr.txt
cp -v _stdout.txt _stderr.txt "$USER_OUTPUT_DIR"/
echo "[run] finished OPERA DPS job."
