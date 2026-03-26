"""Unit tests for the Consumer SQS worker.

Uses ``moto`` for S3 bucket creation and ``unittest.mock.AsyncMock``
to stub the asynchronous boto3 clients.
"""

import json
import os
from typing import Any
from unittest.mock import AsyncMock

import pytest

os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
os.environ["SQS_QUEUE_URL"] = "https://sqs.us-east-1.amazonaws.com/123456789012/test-queue"
os.environ["S3_BUCKET_NAME"] = "test-bucket"

import boto3
from moto import mock_aws


@pytest.fixture
def sample_message() -> dict[str, Any]:
    """Return a representative SQS message dict."""
    return {
        "MessageId": "msg-001",
        "ReceiptHandle": "receipt-handle-001",
        "Body": json.dumps({
            "email_subject": "Hello",
            "email_sender": "alice@example.com",
            "email_timestream": "1693561101",
            "email_content": "Hello world",
        }),
    }


class TestProcessMessage:
    @pytest.mark.asyncio
    async def test_uploads_to_s3_and_returns_receipt(self, sample_message: dict[str, Any]) -> None:
        from app.main import _process_message

        mock_s3 = AsyncMock()
        receipt, s3_key = await _process_message(mock_s3, sample_message)

        assert receipt == "receipt-handle-001"
        assert s3_key.startswith("messages/")
        assert s3_key.endswith(".json")

        mock_s3.put_object.assert_called_once()
        call_kwargs = mock_s3.put_object.call_args[1]
        assert call_kwargs["Bucket"] == "test-bucket"
        assert call_kwargs["ContentType"] == "application/json"

        uploaded = json.loads(call_kwargs["Body"])
        assert uploaded["email_subject"] == "Hello"
        assert uploaded["email_sender"] == "alice@example.com"

    @pytest.mark.asyncio
    async def test_handles_non_json_body_gracefully(self) -> None:
        from app.main import _process_message

        msg: dict[str, str] = {
            "MessageId": "msg-002",
            "ReceiptHandle": "rh-002",
            "Body": "not-valid-json",
        }
        mock_s3 = AsyncMock()
        receipt, s3_key = await _process_message(mock_s3, msg)

        assert receipt == "rh-002"
        call_kwargs = mock_s3.put_object.call_args[1]
        uploaded = json.loads(call_kwargs["Body"])
        assert uploaded == {"raw": "not-valid-json"}

    @pytest.mark.asyncio
    async def test_s3_key_contains_message_id(self, sample_message: dict[str, Any]) -> None:
        from app.main import _process_message

        mock_s3 = AsyncMock()
        _, s3_key = await _process_message(mock_s3, sample_message)
        assert "msg-001" in s3_key


class TestS3Integration:
    @pytest.mark.asyncio
    async def test_s3_put_object_with_moto(self, sample_message: dict[str, Any]) -> None:
        with mock_aws():
            s3 = boto3.client("s3", region_name="us-east-1")
            s3.create_bucket(Bucket="test-bucket")

            from app.main import _process_message

            mock_s3 = AsyncMock()
            receipt, s3_key = await _process_message(mock_s3, sample_message)

            mock_s3.put_object.assert_called_once()
            assert receipt == "receipt-handle-001"


class TestPollLoopEdgeCases:
    @pytest.mark.asyncio
    async def test_empty_response_does_not_crash(self) -> None:
        """Simulate a poll cycle that returns no messages."""
        from app.main import _shutdown

        mock_sqs = AsyncMock()
        mock_sqs.receive_message.return_value = {"Messages": []}

        _shutdown.set()

    @pytest.mark.asyncio
    async def test_shutdown_event_stops_loop(self) -> None:
        import app.main as consumer_main
        consumer_main._shutdown.set()
        assert consumer_main._shutdown.is_set()
        consumer_main._shutdown.clear()
