import boto3, os, argparse, random
from urllib.parse import urlparse
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

def download_s3_file(s3, bucket: str, key: str, dest: str) -> str:
    os.makedirs(dest, exist_ok=True)
    out_path = f"{dest}/{os.path.basename(key)}"
    s3.download_file(bucket, key, out_path)
    return out_path

def download_test(output: str):
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

    u = urlparse(sample)      # s3://bucket/key...
    bucket = u.netloc
    key = u.path.lstrip("/")

    asf_s3 = "https://cumulus.asf.alaska.edu/s3credentials"
    s3 = get_s3_client(asf_s3)

    print(f"Downloading {key}")
    out = download_s3_file(s3, bucket, key, output or "/output.")
    print(f"Saved to {out}")

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Download an OPERA DISP granule")
    p.add_argument("--dest", dest="dest", type=str, help="Output directory", default="/output")
    args = p.parse_args()
    download_test(args.dest)
