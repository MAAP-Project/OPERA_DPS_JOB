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
import earthaccess
from s3fs import S3FileSystem


def parse_args():
    p = argparse.ArgumentParser(
        description="OPERA DISP: stream remote granule, optional water mask, bbox/idx subset, write COG."
    )
    p.add_argument("--short-name", default="OPERA_L3_DISP-S1_V1",
                   help="CMR short name (default: OPERA_L3_DISP-S1_V1)")
    p.add_argument("--temporal", default=None,
                   help="Temporal range 'YYYY-MM-DDTHH:MM:SSZ,YYYY-MM-DDTHH:MM:SSZ'")
    p.add_argument("--bbox", default=None,
                   help="WGS84 bbox 'minx,miny,maxx,maxy'")
    p.add_argument("--limit", type=int, default=10, help="Max granules to search (default 10)")
    p.add_argument("--granule-ur", default=None,
                   help="Optional fixed GranuleUR to open.")
    p.add_argument("--water-mask", default=None,
                   help="Optional water mask raster path (GeoTIFF).")
    p.add_argument("--tile", type=int, default=256, help="COG tile size (default 256)")
    p.add_argument("--compress", default="DEFLATE", help="COG compression (default DEFLATE)")
    p.add_argument("--predictor", type=int, default=2, help="COG predictor (2 for float)")
    p.add_argument("--overview-resampling", default="average",
                   help="COG overview resampling (default average)")
    p.add_argument("--out-name", default="disp_watermasked_subset.cog.tif",
                   help="Output filename (default disp_watermasked_subset.cog.tif)")
    p.add_argument("--idx-window", default=None,
                   help="Optional index window 'y0:y1,x0:x1'")

    args, _ = p.parse_known_args()  # 👈 this makes it Jupyter-safe
    return args



# ----------------- Helpers -----------------
def parse_bbox(bbox_str: str) -> Tuple[float, float, float, float]:
    vals = [float(v) for v in bbox_str.split(",")]
    if len(vals) != 4:
        raise ValueError("bbox must be 'minx,miny,maxx,maxy'")
    return tuple(vals)  # type: ignore


def ensure_wgs84_bbox_to_target(bbox: Tuple[float, float, float, float],
                                target_crs: Any) -> Tuple[float, float, float, float]:
    """Transform a WGS84 bbox to target CRS (x,y)."""
    if not target_crs:
        return bbox
    t = pyproj.Transformer.from_crs("EPSG:4326", target_crs, always_xy=True).transform
    minx, miny, maxx, maxy = bbox
    return shp_transform(t, box(minx, miny, maxx, maxy)).bounds


def _extract_s3_url_from_result(r) -> Optional[str]:
    """
    Try multiple shapes to get an s3://... URL from a MAAP searchGranule result.
    """
    # Result object path
    if hasattr(r, "getDownloadUrl"):
        try:
            url = r.getDownloadUrl()
            if isinstance(url, str) and url.startswith("s3://"):
                return url
        except Exception:
            pass

    # Dict shapes
    if isinstance(r, dict):
        # 1) Direct URL field
        for k in ("url", "URL", "download_url", "DownloadURL"):
            if k in r and isinstance(r[k], str) and r[k].startswith("s3://"):
                return r[k]
        # 2) CMR OnlineAccessURLs
        try:
            urls = r["Granule"]["OnlineAccessURLs"]["OnlineAccessURL"]
            if isinstance(urls, list):
                # prefer s3; otherwise first string
                for u in urls:
                    ustr = u.get("URL") if isinstance(u, dict) else u
                    if isinstance(ustr, str) and ustr.startswith("s3://"):
                        return ustr
                # fallback to first URL if present
                u0 = urls[0].get("URL") if isinstance(urls[0], dict) else urls[0]
                if isinstance(u0, str) and u0.startswith("s3://"):
                    return u0
            elif isinstance(urls, dict):
                u0 = urls.get("URL")
                if isinstance(u0, str) and u0.startswith("s3://"):
                    return u0
        except Exception:
            pass

    return None


def pick_granule_url(maap: MAAP, short_name: str, temporal: Optional[str],
                     bbox: Optional[str], limit: int,
                     fixed_ur: Optional[str] = None) -> Tuple[str, Dict[str, Any]]:
    """
    Robustly pick a granule and return (s3_url, {'granule': <raw>, 'aws_creds': {...}}),
    using only MAAP SDK (no earthaccess dependency or 'Meta' fields).
    """
    # Find collection concept-id (not strictly needed, but keeps query narrow)
    coll = maap.searchCollection(cmr_host="cmr.earthdata.nasa.gov", short_name=short_name)
    if not coll:
        raise RuntimeError(f"No collection found for short_name={short_name}")
    concept_id = coll[0].get("concept-id", None)

    q = {"cmr_host": "cmr.earthdata.nasa.gov"}
    if concept_id:
        q["concept_id"] = concept_id
    if temporal:
        q["temporal"] = temporal
    if bbox:
        q["bounding_box"] = bbox

    results = maap.searchGranule(limit=limit, **q)
    if not results:
        raise RuntimeError("No granules match search.")

    # Pick by UR if requested; otherwise first
    def _granule_ur(r):
        if isinstance(r, dict):
            return r.get("Granule", {}).get("GranuleUR") or r.get("GranuleUR")
        return getattr(r, "GranuleUR", None)

    pick = None
    if fixed_ur:
        for r in results:
            if _granule_ur(r) == fixed_ur:
                pick = r
                break
        if pick is None:
            raise RuntimeError(f"GranuleUR '{fixed_ur}' not found in results.")
    else:
        pick = results[0]

    s3_url = _extract_s3_url_from_result(pick)
    if not s3_url:
        # As a fallback, many MAAP Result objects still support getDownloadUrl()
        if hasattr(pick, "getDownloadUrl"):
            s3_url = pick.getDownloadUrl()
    if not (isinstance(s3_url, str) and s3_url.startswith("s3://")):
        raise RuntimeError("Could not resolve an s3:// download URL from the granule result.")

       # Get short-lived AWS creds for ASF Cumulus
    # IMPORTANT: pass the *endpoint*, not the s3:// object URL
    asf_creds_endpoint = "https://cumulus.asf.alaska.edu/s3credentials"
    aws_creds = maap.aws.earthdata_s3_credentials(asf_creds_endpoint)

    return s3_url, {"granule": pick, "aws_creds": aws_creds}

def open_remote_dataset(granule_url: str, aws_creds: dict) -> xr.Dataset:
    import os, traceback
    from s3fs import S3FileSystem

    os.environ.setdefault("HDF5_USE_FILE_LOCKING", "FALSE")

    s3 = S3FileSystem(
        key=aws_creds["accessKeyId"],
        secret=aws_creds["secretAccessKey"],
        token=aws_creds["sessionToken"],
        client_kwargs={"region_name": "us-west-2"},
        config_kwargs={"max_pool_connections": 32},
    )

    # sanity check
    try:
        _ = s3.info(granule_url)
    except Exception as e:
        raise RuntimeError(f"S3 access failed for {granule_url}: {e}")

    errors = []

    def _try_h5netcdf_fileobj():
        # 🔧 removed cache_type='blockcache' to avoid BlockCache path
        fobj = s3.open(granule_url, "rb")  # no blockcache
        return xr.open_dataset(
            fobj,
            engine="h5netcdf",
            chunks=None,  # no dask required
            driver_kwds={"page_buf_size": 16 * 1024 * 1024, "rdcc_nbytes": 4 * 1024 * 1024},
        )

    def _try_netcdf4_fileobj():
        fobj = s3.open(granule_url, "rb")
        return xr.open_dataset(fobj, engine="netcdf4", chunks=None)

    def _try_scipy_fileobj():
        fobj = s3.open(granule_url, "rb")
        return xr.open_dataset(fobj, engine="scipy", chunks=None)

    for label, fn in [
        ("h5netcdf (fileobj)", _try_h5netcdf_fileobj),
        ("netcdf4 (fileobj)",  _try_netcdf4_fileobj),
        ("scipy (fileobj)",    _try_scipy_fileobj),
    ]:
        try:
            ds = fn()
            _ = list(ds.sizes.items())[:1]  # force a tiny read
            return ds
        except Exception as e:
            tb = "".join(traceback.format_exception_only(type(e), e)).strip().splitlines()[-1]
            errors.append(f"{label}: {tb}")

    raise RuntimeError(f"Failed to open {granule_url}. First errors: {' | '.join(errors[:3])}")

    # Helper: attempt open with a given engine using a file-object
    def _try_fileobj(engine: str, **kwargs):
        fobj = s3.open(granule_url, "rb", cache_type="blockcache", block_size=8 * 1024 * 1024)
        return xr.open_dataset(fobj, engine=engine, chunks="auto", **kwargs)

    # Helper: attempt open with URL string + storage_options
    def _try_url(engine: str, **kwargs):
        return xr.open_dataset(
            granule_url,
            engine=engine,
            chunks="auto",
            backend_kwargs={"storage_options": {
                "key": aws_creds["accessKeyId"],
                "secret": aws_creds["secretAccessKey"],
                "token": aws_creds["sessionToken"],
                "client_kwargs": {"region_name": "us-west-2"},
                "config_kwargs": {"max_pool_connections": 32},
            }},
            **kwargs
        )

    # Preferred attempts (h5netcdf with h5py tuning)
    for attempt in [
        ("h5netcdf (fileobj)", _try_fileobj, dict(driver_kwds={"page_buf_size": 16 * 1024 * 1024,
                                                                "rdcc_nbytes": 4 * 1024 * 1024})),
        ("h5netcdf (url)",     _try_url,    dict(driver_kwds={"page_buf_size": 16 * 1024 * 1024,
                                                              "rdcc_nbytes": 4 * 1024 * 1024})),
        ("netcdf4 (fileobj)",  _try_fileobj, {}),
        ("netcdf4 (url)",      _try_url,    {}),
        ("scipy (fileobj)",    _try_fileobj, {}),
        ("scipy (url)",        _try_url,    {}),
    ]:
        label, fn, kwargs = attempt
        try:
            ds = fn("h5netcdf" if "h5netcdf" in label else ("netcdf4" if "netcdf4" in label else "scipy"),
                    **kwargs)
            # Touch a tiny piece to force I/O and surface auth errors now
            _ = list(ds.dims.items())[:1]
            return ds
        except Exception as e:
            # Keep first line of the traceback to make debugging easier
            tb = "".join(traceback.format_exception_only(type(e), e)).strip().splitlines()[-1]
            errors.append(f"{label}: {tb}")

    # If we reach here, all attempts failed — show the first errors for context
    msg = " | ".join(errors[:3])
    raise RuntimeError(f"Failed to open {granule_url}. First errors: {msg}")

    return ds


def get_displacement(ds: xr.Dataset) -> xr.DataArray:
    """Return the displacement variable, with a light heuristic fallback."""
    if "displacement" in ds:
        return ds["displacement"]
    cand = [v for v in ds.data_vars if "disp" in v.lower() and "uncert" not in v.lower()]
    if not cand:
        raise RuntimeError("Could not find displacement variable.")
    return ds[cand[0]]


def subset_bbox(da: xr.DataArray, bbox_wgs84: Tuple[float, float, float, float]) -> xr.DataArray:
    """Clip by bbox given in WGS84; transform to data CRS and clip."""
    if da.rio.crs is None:
        # Try to fetch from grid_mapping or assume EPSG:4326
        da = da.rio.write_crs(da.rio.crs or "EPSG:4326")
    dst_bbox = ensure_wgs84_bbox_to_target(bbox_wgs84, da.rio.crs)
    return da.rio.clip_box(*dst_bbox)


def subset_idx(da: xr.DataArray, idx_spec: str) -> xr.DataArray:
    """Index slice 'y0:y1,x0:x1'."""
    yspec, xspec = idx_spec.split(",")
    y0, y1 = [int(x) if x else None for x in yspec.split(":")]
    x0, x1 = [int(x) if x else None for x in xspec.split(":")]
    return da.isel(y=slice(y0, y1), x=slice(x0, x1))


def load_water_mask(path: str, like: xr.DataArray) -> xr.DataArray:
    """
    Load a water-mask raster (GeoTIFF or similar), reproject & align to 'like'.
    Any value > 0 is considered water (True). Returns boolean DataArray aligned to 'like'.
    """
    wm = xr.open_dataarray(path)
    # Ensure it has georeferencing
    if wm.rio.crs is None and like.rio.crs is not None:
        wm = wm.rio.write_crs(like.rio.crs)
    wm = wm.rio.reproject_match(like)
    # Collapse band dimension if present
    if "band" in wm.dims and wm.sizes.get("band", 1) == 1:
        wm = wm.isel(band=0, drop=True)
    return (wm > 0).transpose(*like.dims)


def write_cog(da: xr.DataArray, out_path: str,
              nodata_val: float = -9999.0,
              tile: int = 256,
              compress: str = "DEFLATE",
              predictor: int = 2,
              overview_resampling: str = "average") -> str:
    """Write a COG via rioxarray -> rasterio COG driver (robust to Dataset/NaNs)."""

    # If a Dataset slipped in, take the first variable
    if isinstance(da, xr.Dataset):
        if not da.data_vars:
            raise ValueError("write_cog received an empty Dataset.")
        da = next(iter(da.data_vars.values()))

    # Ensure 2D
    if "time" in da.dims:
        da = da.isel(time=0)

    # Be explicit about dtype and nodata
    da = da.rio.write_nodata(nodata_val, inplace=False)

    # Robust array extraction (avoids the .values attribute issue)
    arr = da.to_numpy()  # equivalent to np.asarray(da)
    arr = np.where(np.isnan(arr), nodata_val, arr).astype("float32")

    # Rebuild a clean DataArray with same georeferencing
    da2 = xr.DataArray(
        arr, dims=da.dims,
        coords={k: da.coords[k] for k in da.dims if k in da.coords},
        attrs=da.attrs
    )
    if da.rio.crs is not None:
        da2 = da2.rio.write_crs(da.rio.crs, inplace=False)
    da2 = da2.rio.write_transform(da.rio.transform(), inplace=False)

    da2.rio.to_raster(
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
    return out_path



# ----------------- Main -----------------
def main():
    args = parse_args()

    out_dir = os.environ.get("USER_OUTPUT_DIR", "/output")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, args.out_name)

    # 1) Search & resolve remote URL + S3 creds
    maap = MAAP()
    url, meta = pick_granule_url(maap, args.short_name, args.temporal, args.bbox, args.limit, args.granule_ur)

    # 2) Open remote dataset
    ds = open_remote_dataset(url, meta["aws_creds"])

    # 3) Displacement (no temporal_coherence masking)
    disp = get_displacement(ds)

    # 4) Optional water mask
    if args.water_mask:
        wm_bool = load_water_mask(args.water_mask, like=disp)
        wm_bool, disp = xr.align(wm_bool, disp, join="exact", copy=False)
        disp = disp.where(~wm_bool)

    # 5) Spatial subset
    if args.idx_window:
        disp_sub = subset_idx(disp, args.idx_window)
    elif args.bbox:
        disp_sub = subset_bbox(disp, parse_bbox(args.bbox))
    else:
        disp_sub = disp  # caution: big!

    # 6) Write COG
    out = write_cog(
        disp_sub, out_path,
        tile=args.tile,
        compress=args.compress,
        predictor=args.predictor,
        overview_resampling=args.overview_resampling
    )

    # 7) Stable symlink (optional)
    link_name = os.path.join(out_dir, "displacement_masked.tif")
    try:
        if os.path.islink(link_name) or os.path.exists(link_name):
            os.unlink(link_name)
        os.symlink(os.path.basename(out), link_name)
    except Exception as e:
        print(f"[symlink] warning: {e}")

    # 8) Report
    if os.path.exists(out):
        sz = os.path.getsize(out) / 1e6
        print(json.dumps({"status": "OK", "outfile": out, "size_mb": round(sz, 2)}))
    else:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
