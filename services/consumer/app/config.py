"""Configuration loaded from environment variables with sensible defaults."""

import os

AWS_REGION: str = os.getenv("AWS_REGION", "eu-west-1")
SQS_QUEUE_URL: str = os.getenv("SQS_QUEUE_URL", "")
S3_BUCKET_NAME: str = os.getenv("S3_BUCKET_NAME", "")
SQS_WAIT_TIME_SECONDS: int = int(os.getenv("SQS_WAIT_TIME_SECONDS", "20"))
SQS_MAX_MESSAGES: int = int(os.getenv("SQS_MAX_MESSAGES", "10"))
