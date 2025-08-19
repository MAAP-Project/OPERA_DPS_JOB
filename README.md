# OPERA Surface Displacement DPS JOB

A simple algorithm to test running the OPERA Surface Displacement workflow on MAAP.

## Registering the algorithm
```
Repository URL = https://github.com/HarshiniGirish/OPERA_DPS_JOB.git
Repository Branch = main
Run Command = OPERA_DPS_JOB/run.sh
Build Command = OPERA_DPS_JOB/build.sh
Algorithm Name = operasurfacedisplacement
Description = OPERA Surface Displacement
Disk Space (GB) = 10
Resource = maap-dps-worker-8gb
Container URL = mas.maap-project.org/root/maap-workspaces/base_images/pangeo:v4.1.1

```


## Running the algorithm

```
from maap.maap import MAAP
maap = MAAP()

maap.submitJob(
    identifier="test-run",
    algo_id="operasurfacedisplacement",
    version="main",
    queue="maap-dps-worker-8gb",
)
```

