# OPERA Surface Displacement DPS JOB



Export the OPERA Surface Displacement “water_mask” layer from a granule into a tiled, compressed Cloud-Optimized GeoTIFF (COG). You can either:

Discover a granule via CMR (by short name, time window, optional bbox, and optional specific GranuleUR), or

Bypass discovery and open a known s3:// granule directly.

Optional subsetting is supported by index window or geographic bounding box. Output is a uint8 COG with overviews (good defaults for masks).

## Inputs (CLI flags)

--short-name (default OPERA_L3_DISP-S1_V1): CMR collection to query.

--temporal: 'startZ,endZ' in ISO8601; limits the CMR search.

--bbox: 'minx,miny,maxx,maxy' in WGS84; limits CMR search and can also subset the raster.

--limit: cap the number of granules returned.

--granule-ur: pick an exact granule if you know the UR.

--s3-url: skip CMR and open this s3://…nc directly.

--idx-window: pixel index subsetting in the form y0:y1,x0:x1.

--tile, --compress, --overview-resampling: COG tiling/compression/overview options.

--out-name: filename for the output COG (default water_mask_subset.cog.tif).

Environment: the output directory is pulled from USER_OUTPUT_DIR (falls back to /output).

## Discovery & selection

Collection lookup: uses the MAAP SDK to find the collection’s concept-id by short_name.

Granule search: queries CMR for granules (temporal + bbox filters if provided).

First tries MAAP’s XML/SDK path; if XML parsing fails, it falls back to CMR UMM-JSON.

Respects --granule-ur if supplied.

S3 URL resolution: extracts the s3:// object URL from UMM JSON or the SDK structure.

Temporary AWS credentials: requests short-lived creds from ASF’s s3credentials endpoint so we can read the file.

If --s3-url is provided, the script skips discovery and only fetches credentials.

## Opening the granule

Uses s3fs with the temporary credentials.

Tries xarray with engines in order: h5netcdf, then netcdf4, then scipy.

Opens the remote NetCDF/HDF file as a dataset (no explicit chunking is set here).

Getting the mask & optional subsetting

Extracts the water_mask variable from the dataset.

Handles common dimension patterns (time, band) to get a 2D slice.

Converts to a boolean mask (> 0).

If --idx-window is set: pixel index slice via isel.

Else if --bbox is set: reprojects the WGS84 bbox into the data CRS (via pyproj), then crops (rio.clip_box).

Writing the COG

Casts to uint8, sets nodata = 255.

## Writes a COG with:

block size = --tile (default 256),

compression = --compress (default DEFLATE),

overviews built with --overview-resampling (default nearest, appropriate for masks),

BIGTIFF=IF_NEEDED.

Output path is <USER_OUTPUT_DIR or /output>/<out-name>.



## Registering the algorithm
```
Repository URL = https://github.com/MAAP-Project/OPERA_DPS_JOB.git
Repository Branch = main
Run Command = OPERA_DPS_JOB/run.sh
Build Command = OPERA_DPS_JOB/build.sh
Algorithm Name = operawatermask1
Description = main
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
