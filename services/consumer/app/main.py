"""Consumer worker — long-polls SQS, uploads payloads to S3, then deletes the message.

Runs as a standalone process (no HTTP server). Graceful shutdown is
triggered by SIGINT / SIGTERM.
"""

import asyncio
import json
import logging
import os
import signal
import uuid
from datetime import datetime, timezone
from typing import Any

import aioboto3

from app.config import (
    AWS_REGION,
    S3_BUCKET_NAME,
    SQS_MAX_MESSAGES,
    SQS_QUEUE_URL,
    SQS_WAIT_TIME_SECONDS,
)
from shared.logging_setup import setup_logging

setup_logging("consumer")
logger = logging.getLogger(__name__)

_APP_TEST_MODE: bool = os.getenv("APP_TEST_MODE", "").lower() in {"1", "true", "yes", "on"}

_shutdown = asyncio.Event()


def _handle_signal() -> None:
    """Set the shutdown event so the poll loop drains gracefully."""
    logger.info("Shutdown signal received – draining…")
    _shutdown.set()


async def _process_message(s3_client: Any, message: dict[str, Any]) -> tuple[str, str]:
    """Upload *message* payload to S3 and return ``(receipt_handle, s3_key)``."""
    body: str = message["Body"]
    receipt_handle: str = message["ReceiptHandle"]
    message_id: str = message["MessageId"]

    try:
        payload: dict[str, Any] = json.loads(body)
    except json.JSONDecodeError:
        payload = {"raw": body}

    now = datetime.now(timezone.utc)
    s3_key = f"messages/{now:%Y/%m/%d}/{message_id}-{uuid.uuid4().hex[:8]}.json"

    await s3_client.put_object(
        Bucket=S3_BUCKET_NAME,
        Key=s3_key,
        Body=json.dumps(payload, ensure_ascii=False),
        ContentType="application/json",
    )

    logger.info("Uploaded message %s to s3://%s/%s", message_id, S3_BUCKET_NAME, s3_key)
    return receipt_handle, s3_key


async def _poll_loop() -> None:
    """Continuously long-poll SQS and process each batch of messages."""
    if _APP_TEST_MODE:
        logger.info("Consumer started – APP_TEST_MODE enabled (no AWS clients will be created)")
        while not _shutdown.is_set():
            await asyncio.sleep(1)
        logger.info("Consumer shut down gracefully")
        return

    session = aioboto3.Session()

    async with session.client("sqs", region_name=AWS_REGION) as sqs, session.client(
        "s3", region_name=AWS_REGION
    ) as s3:
        logger.info("Consumer started – polling %s", SQS_QUEUE_URL)

        while not _shutdown.is_set():
            try:
                resp: dict[str, Any] = await sqs.receive_message(
                    QueueUrl=SQS_QUEUE_URL,
                    MaxNumberOfMessages=SQS_MAX_MESSAGES,
                    WaitTimeSeconds=SQS_WAIT_TIME_SECONDS,
                )
            except Exception:
                logger.exception("Error receiving messages – backing off 5 s")
                await asyncio.sleep(5)
                continue

            messages: list[dict[str, Any]] = resp.get("Messages", [])
            if not messages:
                continue

            logger.info("Received %d message(s)", len(messages))

            for msg in messages:
                try:
                    receipt_handle, _ = await _process_message(s3, msg)
                    await sqs.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=receipt_handle,
                    )
                except Exception:
                    logger.exception("Failed to process message %s", msg.get("MessageId"))

    logger.info("Consumer shut down gracefully")


def main() -> None:
    """Entry-point — sets up the event loop, signal handlers, and starts polling."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _handle_signal)
        except NotImplementedError:
            signal.signal(sig, lambda *_: _handle_signal())

    try:
        loop.run_until_complete(_poll_loop())
    finally:
        loop.close()


if __name__ == "__main__":
    main()
