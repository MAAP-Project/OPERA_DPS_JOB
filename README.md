# OPERA_DPS_JOB

A simple algorithm to test running the OPERA Surface Displacement workflow on MAAP.

## Registering the algorithm

Repository URL = https://github.com/HarshiniGirish/OPERA_DPS_JOB.git

Repository Branch = main
Run Command = OPERA_DPS_JOB/run.sh
Build Command = OPERA_DPS_JOB/build.sh
Algorithm Name = OPERA_DISP
Description = OPERA Surface Displacement
Disk Space (GB) = 10
Resource Allocation = maap-dps-worker-8gb
Container URL = mas.maap-project.org/root/maap-workspaces/base_images/pangeo:v4.1.1

Repository URL = https://github.com/HarshiniGirish/OPERA_DPS_JOB.git

Repository Branch = main
Run Command = OPERA_DPS_JOB/run.sh
Build Command = OPERA_DPS_JOB/build.sh
Algorithm Name = OPERA_DISP
Description = OPERA Surface Displacement
Disk Space (GB) = 10
Resource Allocation = maap-dps-worker-8gb
Container URL = mas.maap-project.org/root/maap-workspaces/base_images/pangeo:v4.1.1
Outputs will be available in your MAAP workspace under:

/projects/<your-username>/dps_output/<job-id>/
