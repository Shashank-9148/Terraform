variable "rapidapi_key" {
  description = "API key for RapidAPI"
  type        = string
}

variable "rapidapi_host" {
  description = "Host for RapidAPI"
  type        = string
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "ap-south-1"
}
variable "project" { default = "sports-highlights" }
variable "instance_type" { default = "t3.micro" }
variable "key_name" { default = "sports-highlights-pipeline" }
variable "allowed_ssh_cidr" { default = "0.0.0.0/0" }

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  suffix = random_id.suffix.hex
  name_prefix = "${var.project}-${local.suffix}"
}

#######################
# S3 buckets
#######################
resource "aws_s3_bucket" "metadata" {
  bucket = "${local.name_prefix}-metadata"
  force_destroy = true
}

resource "aws_s3_bucket" "videos" {
  bucket = "${local.name_prefix}-videos"
  force_destroy = true
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"
  force_destroy = true
}

#######################
# ECR
#######################
resource "aws_ecr_repository" "app" {
  name                 = "${local.name_prefix}-app"
  image_tag_mutability = "MUTABLE"
}

#######################
# IAM - EC2 role
#######################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_policy" {
  statement {
    sid = "S3Access"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.metadata.arn,
      "${aws_s3_bucket.metadata.arn}/*",
      aws_s3_bucket.videos.arn,
      "${aws_s3_bucket.videos.arn}/*",
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }

  statement {
    sid = "ECRPull"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability"
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid = "MediaConvert"
    actions = [
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:CreateJob",
      "mediaconvert:GetJob"
    ]
    resources = ["*"]
  }

  # allow EC2 to pass the MediaConvert role
  statement {
    sid = "PassRole"
    actions = ["iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "${local.name_prefix}-ec2-policy"
  policy = data.aws_iam_policy_document.ec2_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_ec2_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

#######################
# IAM - MediaConvert role
#######################
data "aws_iam_policy_document" "mediaconvert_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["mediaconvert.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "mediaconvert_role" {
  name               = "${local.name_prefix}-mediaconvert-role"
  assume_role_policy = data.aws_iam_policy_document.mediaconvert_assume.json
}

data "aws_iam_policy_document" "mediaconvert_policy" {
  statement {
    actions = ["s3:GetObject","s3:PutObject","s3:ListBucket"]
    resources = [
      aws_s3_bucket.videos.arn,
      "${aws_s3_bucket.videos.arn}/*",
      aws_s3_bucket.metadata.arn,
      "${aws_s3_bucket.metadata.arn}/*"
    ]
  }

  statement {
    actions = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "mediaconvert_policy" {
  name   = "${local.name_prefix}-mediaconvert-policy"
  policy = data.aws_iam_policy_document.mediaconvert_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_mediaconvert_policy" {
  role       = aws_iam_role.mediaconvert_role.name
  policy_arn = aws_iam_policy.mediaconvert_policy.arn
}

#######################
# Security group & EC2
#######################
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ec2_sg" {
  name   = "${local.name_prefix}-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

#######################
# EC2 Instance
#######################
resource "aws_instance" "pipeline" {
  ami                    = data.aws_ami.amazon_linux2.id
  instance_type          = var.instance_type
  key_name               = "new-sports-key"
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  # Use heredoc for shell script
  user_data = <<-EOF
              #!/bin/bash
              set -xe
              yum update -y
              amazon-linux-extras install docker -y || yum install -y docker
              service docker start
              usermod -a -G docker ec2-user

              # Install AWS CLI if not present
              if ! command -v aws &> /dev/null; then
                  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
                  unzip /tmp/awscliv2.zip -d /tmp
                  /tmp/aws/install
              fi

              # Optional: create a run script for your container
              cat <<'RUN' > /home/ec2-user/run_container.sh
              #!/bin/bash
              TAG=latest
              docker pull ${aws_ecr_repository.app.repository_url}:$TAG
              docker run -d --restart unless-stopped --name sports-pipeline \
                  -e AWS_REGION=$REGION \
                  -e S3_METADATA_BUCKET=${aws_s3_bucket.metadata.bucket} \
                  -e S3_VIDEOS_BUCKET=${aws_s3_bucket.videos.bucket} \
                  -e S3_LOGS_BUCKET=${aws_s3_bucket.logs.bucket} \
                  -e RAPIDAPI_KEY='${replace(var.rapidapi_key, "'", "\\'")}' \
                  -e RAPIDAPI_HOST='${replace(var.rapidapi_host, "'", "\\'")}' \
                  -e MEDIACONVERT_ROLE_ARN='${aws_iam_role.mediaconvert_role.arn}' \
                  ${aws_ecr_repository.app.repository_url}:$TAG
              RUN

              # Run it in background and log
              /home/ec2-user/run_container.sh > /home/ec2-user/run_container.log 2>&1 &
              EOF

  tags = {
    Name = "sports-highlights-pipeline"
  }

  depends_on = [
    aws_iam_role_policy_attachment.attach_ec2_policy
  ]
}




#######################
# Outputs
#######################
output "metadata_bucket" {
  value = aws_s3_bucket.metadata.bucket
}

output "videos_bucket" {
  value = aws_s3_bucket.videos.bucket
}

output "logs_bucket" {
  value = aws_s3_bucket.logs.bucket
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ec2_public_ip" {
  value = aws_instance.pipeline.public_ip
}
