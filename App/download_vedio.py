import requests
from logger_setup import get_logger

logger = get_logger(__name__)

def download_video_to_s3(s3_client, url, bucket, key):
    logger.info("Downloading %s", url)
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        s3_client.upload_fileobj(r.raw, bucket, key)
    logger.info("Uploaded video to s3://%s/%s", bucket, key)
