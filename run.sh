# !/bin/bash
set -euo pipefail

# always run from the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[run] CWD: $(pwd)"
echo "[run] python: $(python -V)"
ls -lah

# sanity check
test -f asf-s1-edc.py || { echo "[run] ERROR: asf-s1-edc.py not found here"; exit 1; }

echo "[run] starting OPERA DPS job..."
python asf-s1-edc.py
echo "[run] finished OPERA DPS job."
