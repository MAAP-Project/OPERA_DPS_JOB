#!/bin/bash
set -Eeuo pipefail

# If the platform sends SIGTERM (timeout/preemption), save logs and exit 143
trap 'echo "[run] SIGTERM received (likely timeout/preemption). Saving logs..."; \
      mkdir -p /output; cp -v _stdout.txt _stderr.txt /output/ || true; exit 143' TERM

# Work from the repo folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[run] CWD: $(pwd)"
echo "[run] python: $(python -V)"
echo "[run] which python: $(which python)"
echo "[run] which pip: $(which pip)"

# Make sure PROJ knows where proj.db is (removes those warnings)
export PROJ_LIB="${PROJ_LIB:-/opt/conda/envs/python/share/proj}"
[ -d "$PROJ_LIB" ] || PROJ_LIB="/opt/conda/share/proj"
export PROJ_LIB

# DPS collects ABSOLUTE /output
export USER_OUTPUT_DIR=/output
mkdir -p "$USER_OUTPUT_DIR"

# Script must exist
test -f asf-s1-edc.py || { echo "[run] ERROR: asf-s1-edc.py not found"; exit 1; }

echo "[run] starting OPERA DPS job..."
# Stream logs to console AND keep copies we can upload
python asf-s1-edc.py > >(tee _stdout.txt) 2> >(tee _stderr.txt >&2)
rc=$?

# Always publish logs
cp -v _stdout.txt _stderr.txt "$USER_OUTPUT_DIR"/ || true
echo "[run] finished with rc=$rc"
exit $rc
