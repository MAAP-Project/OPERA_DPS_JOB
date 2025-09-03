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
maap.submitJob(identifier="bnmmo",
    algo_id="operawatermask1",
    version="main",
    queue="maap-dps-worker-8gb",
    short_name="OPERA_L3_DISP-S1_V1",
    temporal="2023-06-01T00:00:00Z,2023-06-10T23:59:59Z",
    bbox="-123.5,37.5,-122.5,38.5",
    limit="5",
    s3_url="s3://asf-cumulus-prod-opera-products/OPERA_L3_DISP-S1_V1/OPERA_L3_DISP-S1_IW_F09157_VV_20221213T020808Z_20230611T020808Z_v1.0_20250416T164302Z/OPERA_L3_DISP-S1_IW_F09157_VV_20221213T020808Z_20230611T020808Z_v1.0_20250416T164302Z.nc")
```
