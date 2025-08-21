# !/bin/bash
set -euo pipefail

echo "[run] starting OPERA DPS job..."
python asf-s1-edc.py
echo "[run] finished OPERA DPS job."
