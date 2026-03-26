"""Configuration loaded from environment variables with sensible defaults."""

import os

AWS_REGION: str = os.getenv("AWS_REGION", "eu-west-1")
SQS_QUEUE_URL: str = os.getenv("SQS_QUEUE_URL", "")
SSM_TOKEN_NAME: str = os.getenv("SSM_TOKEN_NAME", "/async-msg-proc/prod/validation-token")
PORT: int = int(os.getenv("PORT", "8000"))
