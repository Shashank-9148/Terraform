import os, json, random
from datetime import datetime
import boto3
from logger_setup import get_logger, upload_text_to_s3
from fetch_highlights import fetch_highlights
from download_video import download_video_to_s3
from mediaconvert_submit import get_mc_client, submit_job

logger = get_logger(__name__)

def run_pipeline():
    region = os.environ.get("AWS_REGION", "ap-south-1")
    s3_meta = os.environ["S3_METADATA_BUCKET"]
    s3_videos = os.environ["S3_VIDEOS_BUCKET"]
    s3_logs = os.environ["S3_LOGS_BUCKET"]
    league = os.environ.get("LEAGUE", "nba")
    date_str = datetime.utcnow().strftime("%Y-%m-%d")
    s3 = boto3.client("s3", region_name=region)

    try:
        highlights = fetch_highlights(league, date_str)
        # save highlights JSON
        meta_key = f"highlights/{league}/{date_str}/highlights.json"
        s3.put_object(Bucket=s3_meta, Key=meta_key, Body=json.dumps(highlights))
        logger.info("Saved highlights to s3://%s/%s", s3_meta, meta_key)

        # extract candidate URLs (simple recursive scan)
        urls = []
        def scan(o):
            if isinstance(o, dict):
                for v in o.values():
                    scan(v)
            elif isinstance(o, list):
                for i in o:
                    scan(i)
            elif isinstance(o, str):
                if o.startswith("http"):
                    if o.lower().endswith((".mp4",".mov",".m3u8")) or "video" in o:
                        urls.append(o)
        scan(highlights)

        if not urls:
            logger.error("No video URLs found")
            log_key = f"logs/{date_str}/pipeline.log"
            upload_text_to_s3(s3, s3_logs, log_key, "No video URLs found in response")
            return

        chosen = random.choice(urls)
        filename = chosen.split("/")[-1].split("?")[0]
        incoming_key = f"incoming/{league}/{date_str}/{filename}"
        download_video_to_s3(s3, chosen, s3_videos, incoming_key)

        # submit MediaConvert
        mc = get_mc_client(region)
        input_s3_url = f"s3://{s3_videos}/{incoming_key}"
        output_prefix = f"s3://{s3_videos}/processed/{league}/{date_str}/"
        role_arn = os.environ["MEDIACONVERT_ROLE_ARN"]
        resp = submit_job(mc, role_arn, input_s3_url, output_prefix)

        # write log
        log_text = f"{datetime.utcnow().isoformat()} - Success. Input: {input_s3_url}. Job: {resp}\n"
        log_key = f"logs/{date_str}/pipeline.log"
        upload_text_to_s3(s3, s3_logs, log_key, log_text)
    except Exception as e:
        logger.exception("Pipeline failed")
        log_key = f"logs/{datetime.utcnow().strftime('%Y-%m-%d')}/pipeline.log"
        s3 = boto3.client("s3", region_name=region)
        upload_text_to_s3(s3, s3_logs, log_key, f"ERROR: {str(e)}\n")

if __name__ == "__main__":
    # simple run-once; container will be run with cron in EC2 user_data
    run_pipeline()
