import sys
import os
from pathlib import Path



# ==== Begin extracted notebook code ====

import os, random
from urllib.parse import urlparse
import boto3, xarray as xr, numpy as np
from affine import Affine
import rioxarray  # registers .rio
from maap.maap import MAAP
maap = MAAP()

def get_s3_creds(url: str):
    return maap.aws.earthdata_s3_credentials(url)

def get_s3_client(s3_cred_endpoint: str):
    creds = get_s3_creds(s3_cred_endpoint)
    session = boto3.Session(
        aws_access_key_id=creds["accessKeyId"],
        aws_secret_access_key=creds["secretAccessKey"],
        aws_session_token=creds["sessionToken"],
    )
    return session.client("s3")

def download_s3_file(s3, bucket: str, key: str, dest_dir: str) -> str:
    os.makedirs(dest_dir, exist_ok=True)
    out_path = os.path.join(dest_dir, os.path.basename(key))
    s3.download_file(bucket, key, out_path)
    return out_path

def _infer_regular_grid_transform(x: np.ndarray, y: np.ndarray) -> Affine:
    if x.ndim != 1 or y.ndim != 1 or x.size < 2 or y.size < 2:
        raise ValueError("x and y must be 1D arrays with length >= 2.")
    dx = float(x[1] - x[0])
    dy_raw = float(y[1] - y[0])
    x0 = float(x[0]) - dx / 2.0
    if dy_raw > 0:
        y0 = float(y[-1]) + dy_raw / 2.0
        dy = -abs(dy_raw)
    else:
        y0 = float(y[0]) - dy_raw / 2.0
        dy = dy_raw
    return Affine(dx, 0.0, x0, 0.0, dy, y0)

def _guess_crs(ds: xr.Dataset) -> str:
    for v in ds.data_vars:
        gm = ds[v].attrs.get("grid_mapping")
        if gm and gm in ds.variables:
            spatial_ref = ds[gm].attrs.get("spatial_ref")
            if spatial_ref:
                return spatial_ref
            crs_wkt = ds[gm].attrs.get("crs_wkt")
            if crs_wkt:
                return crs_wkt
    if "spatial_ref" in ds.attrs:
        return ds.attrs["spatial_ref"]
    return "EPSG:4326"

def open_opera_disp(path: str):
    # Try h5netcdf first, then scipy
    try:
        ds = xr.open_dataset(path, engine="h5netcdf")
    except Exception:
        ds = xr.open_dataset(path, engine="scipy")

    x_name = next((c for c in ("x", "lon", "longitude") if c in ds.coords), None)
    y_name = next((c for c in ("y", "lat", "latitude") if c in ds.coords), None)
    if x_name is None or y_name is None:
        for c in ds.coords:
            u = str(ds.coords[c].attrs.get("units", "")).lower()
            if x_name is None and ("degree_east" in u or "degrees_east" in u):
                x_name = c
            if y_name is None and ("degree_north" in u or "degrees_north" in u):
                y_name = c
    if x_name is None or y_name is None:
        raise RuntimeError("Could not identify x/y coordinate names in dataset.")

    x = ds[x_name].values
    y = ds[y_name].values
    if x.ndim != 1 or y.ndim != 1:
        raise RuntimeError("Expected 1D x/y coordinates (regular grid).")

    transform = _infer_regular_grid_transform(x, y)
    crs_val = _guess_crs(ds)

    want = {"displacement": None, "temporal_coherence": None, "uncertainty": None, "layover_shadow_mask": None}
    for v in ds.data_vars:
        vl = v.lower()
        if want["displacement"] is None and (vl == "displacement" or ("disp" in vl and "uncert" not in vl)):
            want["displacement"] = v
        if want["temporal_coherence"] is None and (vl == "temporal_coherence" or "coherence" in vl):
            want["temporal_coherence"] = v
        if want["uncertainty"] is None and (vl == "uncertainty" or "uncert" in vl):
            want["uncertainty"] = v
        if want["layover_shadow_mask"] is None and (vl == "layover_shadow_mask" or ("layover" in vl and "shadow" in vl and "mask" in vl)):
            want["layover_shadow_mask"] = v

    out = {}
    for key, vname in want.items():
        if vname is None:
            continue
        da = ds[vname]
        dims = tuple(da.dims)
        if ("time" in dims) and (y_name in dims) and (x_name in dims):
            da = da.transpose("time", y_name, x_name, missing_dims="ignore")
        elif (y_name in dims) and (x_name in dims):
            da = da.transpose(y_name, x_name, missing_dims="ignore")
        else:
            raise RuntimeError(f"{vname}: expected dims to include ({y_name}, {x_name})")

        da = da.rio.write_crs(crs_val, inplace=False).rio.write_transform(transform, inplace=False)
        out[key] = da

    if "displacement" not in out:
        raise RuntimeError("Could not find 'displacement' variable in the dataset.")
    return out

def download_and_open(output_dir: str):
    results = maap.searchGranule(
        cmr_host="cmr.earthdata.nasa.gov",
        short_name="OPERA_L3_DISP-S1_V1",
        bounding_box="-124.8136026553671,32.445063449213436,-113.75989347462286,42.24498423828791",
        limit=20,
        temporal="2023-06-01T00:00:00Z,2030-06-12T23:59:59Z",
    )
    if not results:
        raise RuntimeError("No granules found for the query.")
    sample = results[random.randrange(0, len(results))].getDownloadUrl()
    u = urlparse(sample)
    bucket, key = u.netloc, u.path.lstrip("/")

    s3 = get_s3_client("https://cumulus.asf.alaska.edu/s3credentials")
    print(f"[download] {bucket}/{key}")
    local_path = download_s3_file(s3, bucket, key, output_dir or "/output")
    print(f"[download] saved -> {local_path}")

    # ---------- Step 2: Open ----------
    vars_map = open_opera_disp(local_path)

    # ---------- Step 3: Apply mask ----------
    # Mask if temporal_coherence < 0.2  OR layover_shadow_mask == 1
    disp = vars_map["displacement"]
    mask = None

    if "temporal_coherence" in vars_map:
        tc = vars_map["temporal_coherence"]
        # broadcast to displacement's dims if needed
        tc_b, disp_b = xr.align(tc, disp, join="exact", copy=False)
        m_tc = tc_b < 0.2
        mask = m_tc if mask is None else (mask | m_tc)

   
    if mask is not None:
        disp_masked = disp.where(~mask)  # masked → NaN
        vars_map["displacement"] = disp_masked
        disp = disp_masked
    # ----------------------------------

    # Logs
    print("[open] displacement (masked):", disp.shape, disp.dtype)
    print("[open] CRS:", disp.rio.crs)
    print("[open] Transform:", disp.rio.transform())
    for k in ("temporal_coherence", "uncertainty", "layover_shadow_mask"):
        if k in vars_map:
            print(f"[open] {k}:", vars_map[k].shape)

    return local_path, vars_map

# direct call (comment this out if you want to use argparse/__main__ instead)
local_path, vars_map = download_and_open("/tmp/opera_test")

disp = vars_map["displacement"]

# How many pixels got masked?
import numpy as np
masked_frac = np.isnan(disp.values).mean()
print("Masked fraction:", round(masked_frac * 100, 2), "%")

# Quick stats on valid pixels
valid = disp.where(~np.isnan(disp))
print("Valid min/max:", float(valid.min()), float(valid.max()))

from typing import Iterable, Tuple, Dict, Any, Optional
from shapely.geometry import shape, mapping, box
import json
import pyproj
from shapely.ops import transform as shp_transform

def _ensure_bbox_crs(bbox: Tuple[float, float, float, float],
                     src_crs: Any, dst_crs: Any) -> Tuple[float, float, float, float]:
    """Reproject bbox (minx,miny,maxx,maxy) from src_crs → dst_crs."""
    if str(src_crs) == str(dst_crs):
        return bbox
    t = pyproj.Transformer.from_crs(src_crs, dst_crs, always_xy=True).transform
    minx, miny, maxx, maxy = bbox
    g = box(minx, miny, maxx, maxy)
    g2 = shp_transform(t, g).bounds  # returns (minx, miny, maxx, maxy)
    return g2

def subset_by_bbox(da: xr.DataArray,
                   bbox: Tuple[float, float, float, float],
                   bbox_crs: Any = None) -> xr.DataArray:
    """
    Clip by bbox. bbox is (minx, miny, maxx, maxy).
    If bbox_crs is provided and differs from da.rio.crs, it will be reprojected.
    """
    dst_crs = da.rio.crs
    if bbox_crs is not None:
        bbox_in_dst = _ensure_bbox_crs(bbox, bbox_crs, dst_crs)
    else:
        bbox_in_dst = bbox
    # rioxarray expects the box in the data CRS
    return da.rio.clip_box(*bbox_in_dst)

def _load_geojson_geoms(geojson_or_path: Any) -> Iterable[Dict[str, Any]]:
    if isinstance(geojson_or_path, (str, bytes)) and os.path.exists(geojson_or_path):
        gj = json.loads(open(geojson_or_path, "r").read())
    elif isinstance(geojson_or_path, (dict, list)):
        gj = geojson_or_path
    else:
        raise ValueError("Pass a path to a GeoJSON file, or a loaded GeoJSON dict/list.")
    if isinstance(gj, dict) and gj.get("type") == "FeatureCollection":
        geoms = [f["geometry"] for f in gj["features"]]
    elif isinstance(gj, dict) and gj.get("type") in ("Polygon", "MultiPolygon"):
        geoms = [gj]
    elif isinstance(gj, list):
        geoms = [g["geometry"] if "geometry" in g else g for g in gj]
    else:
        raise ValueError("Unsupported GeoJSON structure.")
    return geoms

def subset_by_geojson(da: xr.DataArray,
                      geojson_or_path: Any,
                      aoi_crs: Any) -> xr.DataArray:
    """
    Clip by polygon AOI. aoi_crs is the CRS of the GeoJSON coordinates (e.g., 'EPSG:4326').
    """
    dst_crs = da.rio.crs
    t = pyproj.Transformer.from_crs(aoi_crs, dst_crs, always_xy=True).transform
    geoms = []
    for g in _load_geojson_geoms(geojson_or_path):
        shp = shape(g)
        shp2 = shp_transform(t, shp)
        geoms.append(mapping(shp2))
    # clip() expects a list of GeoJSON-like geometries in the same CRS as the raster
    return da.rio.clip(geoms, dst_crs, drop=True)

def subset_vars_map(vars_map: Dict[str, xr.DataArray],
                    bbox: Optional[Tuple[float, float, float, float]] = None,
                    bbox_crs: Any = None,
                    geojson_or_path: Any = None,
                    aoi_crs: Any = None) -> Dict[str, xr.DataArray]:
    """
    Apply the same spatial subset to each variable present in vars_map.
    - Provide either bbox (+ optional bbox_crs) OR geojson_or_path (+ aoi_crs).
    """
    if (bbox is None) == (geojson_or_path is None):
        raise ValueError("Provide exactly one of: bbox or geojson_or_path.")

    out = {}
    for k, da in vars_map.items():
        if bbox is not None:
            out[k] = subset_by_bbox(da, bbox, bbox_crs=bbox_crs)
        else:
            out[k] = subset_by_geojson(da, geojson_or_path, aoi_crs=aoi_crs)
    return out
bbox_wgs84 = (-124.8136026553671, 32.445063449213436,
              -113.75989347462286, 42.24498423828791)

vars_map_sub = subset_vars_map(
    vars_map,
    bbox=bbox_wgs84,
    bbox_crs="EPSG:4326",   # reprojects to the raster CRS under the hood
)

disp_sub = vars_map_sub["displacement"]
print("subset shape:", disp_sub.shape)

import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.shutil import copy as rio_copy

def save_cog(da, out_path,
             nodata_val=-9999.0,
             tile=256,
             compress="DEFLATE",
             predictor=2,  # NOTE: for float32, many workflows use predictor=3; keep 2 if you prefer
             overview_resampling="average"):
    """
    Save an xarray/rioxarray DataArray as a Cloud-Optimized GeoTIFF (COG) if possible.
    Falls back to a tiled GeoTIFF with internal overviews when COG driver is unavailable.

    Parameters
    ----------
    da : xr.DataArray
        Must have CRS/transform via rioxarray (.rio.crs / .rio.transform()).
    out_path : str
        Destination *.tif path.
    nodata_val : float
        Value to write for masked/NaN pixels.
    tile : int
        Internal tile size (tile x tile).
    compress : str
        'DEFLATE' recommended.
    predictor : int
        2 (horizontal differencing) or 3 (floating-point predictor).
    overview_resampling : str
        'average', 'nearest', etc.
    """
    # Ensure 2D
    if "time" in da.dims:
        da = da.isel(time=0)

    # Make sure nodata is set and NaNs are mapped to nodata
    da = da.rio.write_nodata(nodata_val, inplace=False)
    arr = da.values
    arr_out = np.where(np.isnan(arr), nodata_val, arr).astype("float32")

    # Try direct COG via rioxarray (GDAL COG driver must be available)
    try:
        da_cog = xr.DataArray(
            arr_out,
            dims=da.dims,
            coords={k: da.coords[k] for k in da.dims if k in da.coords},
            attrs=da.attrs,
        )
        da_cog = da_cog.rio.write_crs(da.rio.crs, inplace=False).rio.write_transform(da.rio.transform(), inplace=False)
        da_cog.rio.to_raster(
            out_path,
            driver="COG",
            dtype="float32",
            nodata=nodata_val,
            blockxsize=tile,
            blockysize=tile,
            compress=compress,
            predictor=predictor,
            overview_resampling=overview_resampling,
            BIGTIFF="IF_NEEDED",
        )
        print(f"[cog] wrote COG directly: {out_path}")
        return out_path
    except Exception as e:
        print(f"[cog] direct COG path not available ({e}); falling back to GeoTIFF + overviews…")

    # Fallback: write tiled GeoTIFF, build overviews, then (if possible) convert to COG layout
    tmp = out_path + ".tmp.tif"
    profile = {
        "driver": "GTiff",
        "height": arr_out.shape[0],
        "width":  arr_out.shape[1],
        "count":  1,
        "dtype":  "float32",
        "crs":    da.rio.crs,
        "transform": da.rio.transform(),
        "nodata": nodata_val,
        "tiled": True,
        "blockxsize": tile,
        "blockysize": tile,
        "compress": compress,
        "predictor": predictor,
        "BIGTIFF": "IF_NEEDED",
    }
    with rasterio.open(tmp, "w", **profile) as dst:
        dst.write(arr_out, 1)
        # Internal overviews (pyramids)
        factors = [2, 4, 8, 16, 32]
        dst.build_overviews(factors, getattr(Resampling, overview_resampling))
        dst.update_tags(ns="rio_overview", resampling=overview_resampling)

    # Try to convert to true COG; if COG driver is missing, this will still leave you with a solid tiled GTiff
    try:
        rio_copy(
            tmp, out_path,
            copy_src_overviews=True,
            driver="COG",
            compress=compress,
            predictor=predictor,
            BIGTIFF="IF_NEEDED",
            nodata=nodata_val,
            overview_resampling=overview_resampling,
        )
        os.remove(tmp)
        print(f"[cog] converted to COG: {out_path}")
    except Exception as e:
        # Keep the well-formed tiled GeoTIFF with internal overviews
        print(f"[cog] could not convert to COG ({e}); kept tiled GeoTIFF at: {tmp}")
        return tmp

    return out_path

# Using your subsetted + masked array
to_save = vars_map_sub.get("displacement", vars_map["displacement"])
cog_path = "/tmp/opera_test/disp_masked_subset.cog.tif"
save_cog(to_save, cog_path, tile=256, compress="DEFLATE", predictor=2)

import os

cog_path = "/output/disp_masked_subset.cog.tif"
save_cog(to_save, cog_path)

if os.path.exists(cog_path):
    print(f"✅ File saved at: {cog_path}")
    print(f"Size: {os.path.getsize(cog_path) / 1e6:.2f} MB")
else:
    print(f"❌ File not found at: {cog_path}")



# ==== End extracted notebook code ====


if __name__ == '__main__':
    # If your notebook defined a main() function, call it here.
    # Otherwise, this guard prevents accidental execution on import.
    main_fn = globals().get('main')
    if callable(main_fn):
        sys.exit(main_fn())
    else:
        # No explicit main() found; nothing to do.
        pass
        
        
out_file = "/output/displacement_masked.tif"

disp.rio.to_raster(
    out_file,
    driver="COG",            # Cloud-Optimized GeoTIFF
    tiled=True,
    blockxsize=256,
    blockysize=256,
    compress="DEFLATE",
    predictor=2,
    BIGTIFF="IF_SAFER",
    overwrite=True
)

print(f"[save] wrote GeoTIFF -> {out_file}")
