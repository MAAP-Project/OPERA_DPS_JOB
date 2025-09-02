#!/usr/bin/env python
# OPERA DISP: extract internal water_mask variable, subset by bbox/idx, write as COG.

import os
import json
import argparse
from typing import Any, Dict, Optional, Tuple

import numpy as np
import xarray as xr
import rioxarray  # registers .rio
import pyproj
from shapely.geometry import box
from shapely.ops import transform as shp_transform

from maap.maap import MAAP
from s3fs import S3FileSystem


# ----------------- CLI -----------------
def parse_args():
    p = argparse.ArgumentParser(
        description="OPERA DISP: export water_mask -> COG (uint8), with optional bbox/idx subsetting."
    )
    p.add_argument("--short-name", default="OPERA_L3_DISP-S1_V1", help="CMR short name")
    p.add_argument("--temporal", default=None,
                   help="Temporal range 'YYYY-MM-DDTHH:MM:SSZ,YYYY-MM-DDTHH:MM:SSZ'")
    p.add_argument("--bbox", default=None,
                   help="WGS84 bbox 'minx,miny,maxx,maxy'")
    p.add_argument("--limit", type=int, default=10, help="Max granules to search")
    p.add_argument("--granule-ur", default=None, help="Optional fixed GranuleUR")
    p.add_argument("--tile", type=int, default=256, help="COG tile size")
    p.add_argument("--compress", default="DEFLATE", help="COG compression")
    p.add_argument("--overview-resampling", default="nearest",
                   help="COG overview resampling (nearest for masks)")
    p.add_argument("--out-name", default="water_mask_subset.cog.tif", help="Output filename")
    p.add_argument("--idx-window", default=None, help="Index window 'y0:y1,x0:x1'")
    args, _ = p.parse_known_args()
    return args


# ----------------- Helpers -----------------
def parse_bbox(bbox_str: str) -> Tuple[float, float, float, float]:
    vals = [float(v) for v in bbox_str.split(",")]
    if len(vals) != 4:
        raise ValueError("bbox must be 'minx,miny,maxx,maxy'")
    return tuple(vals)


def ensure_wgs84_bbox_to_target(bbox, target_crs: Any):
    if not target_crs:
        return bbox
    t = pyproj.Transformer.from_crs("EPSG:4326", target_crs, always_xy=True).transform
    minx, miny, maxx, maxy = bbox
    return shp_transform(t, box(minx, miny, maxx, maxy)).bounds


def _extract_s3_url_from_result(r) -> Optional[str]:
    if hasattr(r, "getDownloadUrl"):
        try:
            url = r.getDownloadUrl()
            if isinstance(url, str) and url.startswith("s3://"):
                return url
        except Exception:
            pass
    if isinstance(r, dict):
        for k in ("url", "URL", "download_url", "DownloadURL"):
            if k in r and isinstance(r[k], str) and r[k].startswith("s3://"):
                return r[k]
        try:
            urls = r["Granule"]["OnlineAccessURLs"]["OnlineAccessURL"]
            if isinstance(urls, list):
                for u in urls:
                    ustr = u.get("URL") if isinstance(u, dict) else u
                    if isinstance(ustr, str) and ustr.startswith("s3://"):
                        return ustr
            elif isinstance(urls, dict):
                u0 = urls.get("URL")
                if isinstance(u0, str) and u0.startswith("s3://"):
                    return u0
        except Exception:
            pass
    return None


def pick_granule_url(maap: MAAP, short_name, temporal, bbox, limit, fixed_ur=None):
    coll = maap.searchCollection(cmr_host="cmr.earthdata.nasa.gov", short_name=short_name)
    if not coll:
        raise RuntimeError(f"No collection found for {short_name}")
    concept_id = coll[0].get("concept-id")

    q = {"cmr_host": "cmr.earthdata.nasa.gov"}
    if concept_id: q["concept_id"] = concept_id
    if temporal:   q["temporal"] = temporal
    if bbox:       q["bounding_box"] = bbox

    results = maap.searchGranule(limit=limit, **q)
    if not results:
        raise RuntimeError("No granules found.")

    def _granule_ur(r):
        return r.get("Granule", {}).get("GranuleUR") if isinstance(r, dict) else getattr(r, "GranuleUR", None)

    if fixed_ur:
        pick = next((r for r in results if _granule_ur(r) == fixed_ur), None)
        if pick is None:
            raise RuntimeError(f"GranuleUR '{fixed_ur}' not found")
    else:
        pick = results[0]

    s3_url = _extract_s3_url_from_result(pick) or (pick.getDownloadUrl() if hasattr(pick, "getDownloadUrl") else None)
    if not (isinstance(s3_url, str) and s3_url.startswith("s3://")):
        raise RuntimeError("Could not resolve s3:// URL")

    creds = maap.aws.earthdata_s3_credentials("https://cumulus.asf.alaska.edu/s3credentials")
    return s3_url, {"granule": pick, "aws_creds": creds}


def open_remote_dataset(granule_url: str, aws_creds: dict) -> xr.Dataset:
    os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")
    s3 = S3FileSystem(key=aws_creds["accessKeyId"],
                      secret=aws_creds["secretAccessKey"],
                      token=aws_creds["sessionToken"],
                      client_kwargs={"region_name": "us-west-2"})
    _ = s3.info(granule_url)

    for engine in ["h5netcdf", "netcdf4", "scipy"]:
        try:
            fobj = s3.open(granule_url, "rb")
            ds = xr.open_dataset(fobj, engine=engine, chunks=None)
            _ = list(ds.sizes.items())[:1]
            return ds
        except Exception:
            continue
    raise RuntimeError(f"Failed to open {granule_url}")


def get_water_mask(ds: xr.Dataset) -> xr.DataArray:
    if "water_mask" not in ds:
        raise RuntimeError("Dataset has no 'water_mask' variable.")
    da = ds["water_mask"]
    if "time" in da.dims and da.sizes.get("time", 1) > 1:
        da = da.isel(time=0)
    if "band" in da.dims and da.sizes.get("band", 1) == 1:
        da = da.isel(band=0, drop=True)
    return (da > 0)  # boolean mask


def subset_bbox(da: xr.DataArray, bbox) -> xr.DataArray:
    if da.rio.crs is None:
        da = da.rio.write_crs("EPSG:4326")
    dst_bbox = ensure_wgs84_bbox_to_target(bbox, da.rio.crs)
    return da.rio.clip_box(*dst_bbox)


def subset_idx(da: xr.DataArray, idx_spec: str) -> xr.DataArray:
    yspec, xspec = idx_spec.split(",")
    y0, y1 = [int(x) if x else None for x in yspec.split(":")]
    x0, x1 = [int(x) if x else None for x in xspec.split(":")]
    return da.isel(y=slice(y0, y1), x=slice(x0, x1))


def write_cog(da: xr.DataArray, out_path: str,
              nodata_val=255, tile=256,
              compress="DEFLATE", overview_resampling="nearest"):
    da = da.astype("uint8").rio.write_nodata(nodata_val, inplace=False)
    da.rio.to_raster(out_path,
                     driver="COG",
                     dtype="uint8",
                     nodata=nodata_val,
                     blockxsize=tile,
                     blockysize=tile,
                     compress=compress,
                     overview_resampling=overview_resampling,
                     BIGTIFF="IF_NEEDED")
    return out_path


# ----------------- Main -----------------
def main():
    args = parse_args()
    out_dir = os.environ.get("USER_OUTPUT_DIR", "/output")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, args.out_name)

    maap = MAAP()
    url, meta = pick_granule_url(maap, args.short_name, args.temporal, args.bbox, args.limit, args.granule_ur)
    ds = open_remote_dataset(url, meta["aws_creds"])
    wm = get_water_mask(ds)

    if args.idx_window:
        wm = subset_idx(wm, args.idx_window)
    elif args.bbox:
        wm = subset_bbox(wm, parse_bbox(args.bbox))

    out = write_cog(wm, out_path,
                    tile=args.tile,
                    compress=args.compress,
                    overview_resampling=args.overview_resampling)

    link_name = os.path.join(out_dir, "water_mask.tif")
    try:
        if os.path.exists(link_name) or os.path.islink(link_name):
            os.unlink(link_name)
        os.symlink(os.path.basename(out), link_name)
    except Exception:
        pass

    if os.path.exists(out):
        print(json.dumps({"status": "OK", "outfile": out,
                          "size_mb": round(os.path.getsize(out) / 1e6, 2)}))
    else:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
