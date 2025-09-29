import boto3
from logger_setup import get_logger

logger = get_logger(__name__)

def get_mc_client(region):
    mc = boto3.client("mediaconvert", region_name=region)
    endpoints = mc.describe_endpoints()
    endpoint_url = endpoints["Endpoints"][0]["Url"]
    logger.info("MediaConvert endpoint: %s", endpoint_url)
    return boto3.client("mediaconvert", region_name=region, endpoint_url=endpoint_url)

def submit_job(mc_client, role_arn, input_s3, output_s3_prefix):
    job_settings = {
        "Role": role_arn,
        "Settings": {
            "Inputs": [{"FileInput": input_s3}],
            "OutputGroups": [
                {
                    "Name": "File Group",
                    "OutputGroupSettings": {
                        "Type": "FILE_GROUP_SETTINGS",
                        "FileGroupSettings": {"Destination": output_s3_prefix}
                    },
                    "Outputs": [
                        # 720p
                        {
                            "ContainerSettings": {"Container": "MP4"},
                            "VideoDescription": {
                                "CodecSettings": {
                                    "Codec": "H_264",
                                    "H264Settings": {"RateControlMode": "CBR", "Bitrate": 3000000}
                                },
                                "Height": 720, "Width": 1280
                            }
                        },
                        # 480p
                        {
                            "ContainerSettings": {"Container": "MP4"},
                            "VideoDescription": {
                                "CodecSettings": {
                                    "Codec": "H_264",
                                    "H264Settings": {"RateControlMode": "CBR", "Bitrate": 1000000}
                                },
                                "Height": 480, "Width": 854
                            }
                        }
                    ]
                }
            ]
        }
    }
    resp = mc_client.create_job(**job_settings)
    job_id = resp.get("Job", {}).get("Id")
    logger.info("Submitted MediaConvert job %s", job_id)
    return resp
