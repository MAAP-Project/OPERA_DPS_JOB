# !/bin/bash
set -euo pipefail
basedir=$( cd "$(dirname "$0")" ; pwd -P )

mkdir -p /output
echo "[run.sh] Running download to /output"
python ${basedir}/asf-s1-edc.py --dest /output
echo "[run.sh] Done, contents of /output:"
ls -lh /output
