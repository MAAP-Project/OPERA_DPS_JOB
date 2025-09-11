1) Imports

Brings in standard libraries for JSON, arguments, and XML, plus geospatial/data tools: xarray and rioxarray for reading/writing, pyproj/shapely for coordinate transforms, requests for HTTP calls, maap for CMR/S3 access, and s3fs for S3 file handling.

2) Command-line Interface (CLI)

Defines arguments such as short name, temporal range, bounding box, granule UR, S3 URL, output name, and COG settings. It also trims whitespace in case inputs from UI are messy.

3) Helper Utilities

Provides small functions to parse bounding boxes, reproject them to the dataset CRS, and extract S3 URLs from CMR results or UMM JSON. These ensure consistent handling of search and download metadata.

4) Granule Discovery and Credentials

Searches CMR for granules based on collection, time, and bbox. Uses the MAAP SDK with an XML response first, then falls back to UMM JSON if needed. Once a granule is found, extracts its S3 path and fetches temporary AWS credentials for access.

5) Opening the Dataset

Uses s3fs with the temporary credentials to access the remote NetCDF/HDF file. Tries multiple xarray engines (h5netcdf, netcdf4, scipy) until one succeeds and returns the dataset.

6) Extracting the Water Mask

Selects the water_mask variable from the dataset. If the data has a time dimension or single-band layout, it normalizes to a 2D slice. Finally, it converts the result into a simple boolean mask.

7) Subsetting

Applies optional cropping. If an index window is given, slices directly by pixel rows/columns. If a bounding box is provided, reprojects it and uses rio.clip_box to crop spatially.

8) Writing the COG

Casts the mask to uint8, assigns nodata as 255, and writes a Cloud-Optimized GeoTIFF. The file is tiled, compressed, and includes overviews, producing an efficient binary mask raster.

9) Main Program Flow

Parses inputs, logs them as JSON, resolves the output directory (USER_OUTPUT_DIR or /output), discovers or uses the provided S3 URL, opens the dataset, extracts and subsets the water mask, writes the COG, and prints final status including file size.

10) Output Visibility Problem

Although the script prints that it saved the COG file and shows its size, the file may not appear when inspecting the container. This usually happens if /output during execution is mounted differently than /output in the inspection shell, or if a symlink target is outside the visible filesystem.


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
```
maap.submitJob(identifier="tuesday",
    algo_id="operawatermask1",
    version="feat-v1",
    queue="maap-dps-worker-16gb",
    SHORT_NAME="OPERA_L3_DISP-S1_V1",
    TEMPORAL="2016-07-01T00:00:00Z,2024-12-31T23:59:59Z",
    BBOX="",
    LIMIT="",
    GRANULE_UR="",
    IDX_WINDOW="0:1024,0:1024",
    S3_URL="")
```
