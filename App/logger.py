import logging
from datetime import datetime
import boto3

def get_logger(name=__name__):
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    ch = logging.StreamHandler()
    ch.setFormatter(logging.Formatter('%(asctime)s %(levelname)s %(message)s'))
    logger.addHandler(ch)
    return logger

def upload_text_to_s3(s3_client, bucket, key, text):
    s3_client.put_object(Bucket=bucket, Key=key, Body=text.encode("utf-8"))
