#!/usr/bin/env -S bash -l
set -euo pipefail

source /opt/conda/etc/profile.d/conda.sh
conda activate subset_watermask_cog

/opt/conda/envs/subset_watermask_cog/bin/python /app/OPERA_DPS_JOB/asf-opera-disp-watermask-cog.py "$@"
