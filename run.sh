#!/usr/bin/env -S bash -l
set -euo pipefail

# activate conda
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  source /opt/conda/etc/profile.d/conda.sh
else
  echo "conda.sh not found at /opt/conda/etc/profile.d/conda.sh" >&2
  exit 1
fi

# activate the env created in build.sh
conda activate subset_watermask_cog

# run the main script with any args from DPS
/opt/conda/envs/subset_watermask_cog/bin/python /app/OPERA_DPS_JOB/asf-opera-disp-watermask-cog.py "$@"
