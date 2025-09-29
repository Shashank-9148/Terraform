 Sports Highlights Ingestion & Processing Pipeline
 Project Overview

This project builds a pipeline to fetch sports highlights (from RapidAPI), process videos using AWS MediaConvert, and store outputs in Amazon S3.

It is containerized with Docker, deployed on an EC2 instance, and can be scheduled with EventBridge. Optional notifications can be sent via SNS.

 Architecture

RapidAPI (API-Football) → Fetch highlights metadata

AWS MediaConvert → Process & transcode videos

Amazon S3 → Store:

Metadata (sports-highlights-xxxx-metadata)

Processed videos (sports-highlights-xxxx-videos)

Logs (sports-highlights-xxxx-logs)

EC2 + Docker → Run pipeline in container

EventBridge (Optional) → Schedule jobs

SNS (Optional) → Send notifications

 Project Structure
project/
│── app/
│   ├── pipeline.py              # Main entry point
│   ├── fetch_highlights.py      # Fetch highlights from API
│   ├── download_video.py        # Download video files
│   ├── mediaconvert_submit.py   # Submit jobs to MediaConvert
│   ├── logger.py                # Logging utility
│   ├── requirements.txt         # Python dependencies
│   ├── Dockerfile               # Docker image build
│
└── terraform/                   # (Optional) Terraform infra code

 Setup Instructions
1. Prerequisites

AWS Account with:

S3, EC2, MediaConvert, IAM, EventBridge, SNS

RapidAPI API-Football
 key

Docker installed locally or on EC2

2. Build & Push Docker Image
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t sports-highlights-app:latest .

# Tag image
docker tag sports-highlights-app:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/sports-highlights-app:latest

# Push image
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/sports-highlights-app:latest

3. Run Container on EC2
docker run -d \
  --name sports-pipeline \
  --restart unless-stopped \
  -e AWS_REGION=ap-south-1 \
  -e S3_METADATA_BUCKET=sports-highlights-xxxx-metadata \
  -e S3_VIDEOS_BUCKET=sports-highlights-xxxx-videos \
  -e S3_LOGS_BUCKET=sports-highlights-xxxx-logs \
  -e RAPIDAPI_KEY='<your_rapidapi_key>' \
  -e RAPIDAPI_HOST='api-football.p.rapidapi.com' \
  -e MEDIACONVERT_ROLE_ARN='arn:aws:iam::<ACCOUNT_ID>:role/mediaconvert_role' \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/sports-highlights-app:latest

4. Logs & Debugging
# View logs
docker logs -f sports-pipeline

# Enter container
docker exec -it sports-pipeline /bin/bash

5. Environment Variables
Variable	Description
AWS_REGION	AWS region (e.g., ap-south-1)
S3_METADATA_BUCKET	S3 bucket for metadata
S3_VIDEOS_BUCKET	S3 bucket for processed videos
S3_LOGS_BUCKET	S3 bucket for logs
RAPIDAPI_KEY	Your RapidAPI key
RAPIDAPI_HOST	API host (api-football.p.rapidapi.com)
MEDIACONVERT_ROLE_ARN	IAM role ARN for MediaConvert
 Notes

Ensure your EC2 security group allows port 22 (SSH).

If you face urllib3 v2.0 + OpenSSL 1.0.2 issue, pin dependencies in requirements.txt:

boto3==1.26.0
botocore==1.29.0
urllib3<2



Use EventBridge to schedule the container periodically.
