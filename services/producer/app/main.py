"""Producer FastAPI application.

Receives JSON payloads via HTTP, validates them against the Pydantic
schema, authenticates with a token stored in SSM Parameter Store,
and publishes accepted messages to SQS.
"""

import json
import logging
import os
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Any

import aioboto3
from fastapi import FastAPI, HTTPException, status

from app.config import AWS_REGION, SQS_QUEUE_URL, SSM_TOKEN_NAME
from app.models import MessagePayload
from shared.logging_setup import setup_logging

setup_logging("producer")
logger = logging.getLogger(__name__)

_APP_TEST_MODE: bool = os.getenv("APP_TEST_MODE", "").lower() in {"1", "true", "yes", "on"}

_cached_token: str | None = None
_boto_session: aioboto3.Session | None = None
_sqs_client: Any | None = None
_sqs_cm: Any | None = None


async def _fetch_token_from_ssm() -> str:
    """Return the validation token, fetching from SSM on first call.

    The token is cached in-memory so subsequent requests avoid SSM
    API calls and potential throttling.
    """
    global _cached_token, _boto_session
    if _cached_token is not None:
        return _cached_token

    if _APP_TEST_MODE:
        _cached_token = os.getenv("APP_TEST_TOKEN", "test-secret-token-123")
        return _cached_token

    if _boto_session is None:
        _boto_session = aioboto3.Session()

    async with _boto_session.client("ssm", region_name=AWS_REGION) as ssm:
        resp: dict[str, Any] = await ssm.get_parameter(Name=SSM_TOKEN_NAME, WithDecryption=True)
        _cached_token = resp["Parameter"]["Value"]

    logger.info("Validation token loaded from SSM and cached in memory")
    return _cached_token  # type: ignore[return-value]


async def _ensure_sqs_client() -> None:
    """Open a single long-lived SQS client for the process (lazy, on first publish)."""
    global _sqs_client, _sqs_cm, _boto_session
    if _sqs_client is not None:
        return
    if _boto_session is None:
        _boto_session = aioboto3.Session()
    _sqs_cm = _boto_session.client("sqs", region_name=AWS_REGION)
    _sqs_client = await _sqs_cm.__aenter__()


async def _close_sqs_client() -> None:
    """Close the shared SQS client if it was opened."""
    global _sqs_client, _sqs_cm
    if _sqs_cm is not None:
        await _sqs_cm.__aexit__(None, None, None)
    _sqs_client = None
    _sqs_cm = None


async def publish_message_to_sqs(message_body: dict[str, str]) -> None:
    """Publish *message_body* to SQS using a reused client (one connection per worker)."""
    if _APP_TEST_MODE:
        logger.info("APP_TEST_MODE enabled – skipping SQS publish")
        return
    await _ensure_sqs_client()
    if _sqs_client is None:
        raise RuntimeError("SQS client failed to initialise")
    await _sqs_client.send_message(
        QueueUrl=SQS_QUEUE_URL,
        MessageBody=json.dumps(message_body),
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create boto session for SSM; SQS client opens lazily on first publish."""
    global _boto_session
    _boto_session = aioboto3.Session()
    if not _APP_TEST_MODE:
        try:
            await _fetch_token_from_ssm()
        except Exception:
            logger.warning("Could not pre-fetch SSM token (will retry on first request)")
    yield
    await _close_sqs_client()
    _boto_session = None


app = FastAPI(
    title="Producer API",
    description="Receives email payloads, validates them, and publishes to SQS",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health() -> dict[str, str]:
    """Shallow health-check used by the CLB health check."""
    return {"status": "healthy"}


@app.post("/messages", status_code=status.HTTP_202_ACCEPTED)
async def create_message(payload: MessagePayload) -> dict[str, str]:
    """Validate the incoming payload, authenticate, and publish to SQS."""
    expected_token = await _fetch_token_from_ssm()

    if payload.token != expected_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
        )

    message_body: dict[str, str] = payload.data.model_dump()
    await publish_message_to_sqs(message_body)

    logger.info("Message published to SQS for sender=%s", payload.data.email_sender)
    return {"status": "accepted", "email_sender": payload.data.email_sender}
