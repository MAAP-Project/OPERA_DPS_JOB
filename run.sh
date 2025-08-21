# !/bin/bash
set -euo pipefail

echo "[run] CWD: $(pwd)"
echo "[run] python: $(python -V)"
echo "[run] which python: $(command -v python)"
echo "[run] which pip: $(command -v pip || true)"
python -c "import sys; print('[run] sys.executable =', sys.executable)"

echo "[run] starting OPERA DPS job..."
python asf-s1-edc.py
echo "[run] finished OPERA DPS job."
