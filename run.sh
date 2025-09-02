#!/usr/bin/env -S bash -l
set -euo pipefail

# Make conda available in non-interactive shells
if [ -f /opt/conda/etc/profile.d/conda.sh ]; then
  # shellcheck disable=SC1091
  source /opt/conda/etc/profile.d/conda.sh
else
  echo "conda.sh not found at /opt/conda/etc/profile.d/conda.sh" >&2
  exit 1
fi

# Activate the env built in the image
conda activate subset_watermask_cog

# Avoid leaking user site-packages
export PYTHONNOUSERSITE=1

# Run the job with the env's python
exec /opt/conda/envs/subset_watermask_cog/bin/python \
  /app/OPERA_DPS_JOB/asf-opera-disp-watermask-cog.py "$@"
