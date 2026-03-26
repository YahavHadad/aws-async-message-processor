"""Unit tests for the Producer FastAPI service.

Uses ``moto`` for AWS mocking and ``unittest.mock`` for patching the
async boto3 session so tests run without real credentials.
"""

import json
import os
from collections.abc import Iterator
from typing import Any
from unittest.mock import AsyncMock, patch

import pytest

os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
os.environ["AWS_ACCESS_KEY_ID"] = "testing"
os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
os.environ["SQS_QUEUE_URL"] = "https://sqs.us-east-1.amazonaws.com/123456789012/test-queue"
os.environ["SSM_TOKEN_NAME"] = "/test/token"

import boto3
from fastapi.testclient import TestClient
from moto import mock_aws

VALID_TOKEN: str = "test-secret-token-123"


@pytest.fixture(autouse=True)
def _reset_cached_token() -> Iterator[None]:
    """Reset module-level AWS client state between tests."""
    import app.main as producer_main

    producer_main._cached_token = None
    producer_main._boto_session = None
    producer_main._sqs_client = None
    producer_main._sqs_cm = None
    yield
    producer_main._cached_token = None
    producer_main._boto_session = None
    producer_main._sqs_client = None
    producer_main._sqs_cm = None


@pytest.fixture
def ssm_param() -> Iterator[None]:
    """Provision an SSM SecureString parameter via moto."""
    with mock_aws():
        ssm = boto3.client("ssm", region_name="us-east-1")
        ssm.put_parameter(
            Name="/test/token",
            Value=VALID_TOKEN,
            Type="SecureString",
        )
        yield


@pytest.fixture
def sqs_queue() -> Iterator[str]:
    """Create an SQS queue via moto and yield its URL."""
    with mock_aws():
        sqs = boto3.client("sqs", region_name="us-east-1")
        resp = sqs.create_queue(QueueName="test-queue")
        os.environ["SQS_QUEUE_URL"] = resp["QueueUrl"]
        yield resp["QueueUrl"]


def _make_payload(token: str = VALID_TOKEN, **overrides: str) -> dict[str, Any]:
    """Build a valid request payload, optionally overriding data fields."""
    data: dict[str, str] = {
        "email_subject": "Hello",
        "email_sender": "alice@example.com",
        "email_timestream": "1693561101",
        "email_content": "Test content",
    }
    data.update(overrides)
    return {"data": data, "token": token}


@pytest.fixture
def client() -> TestClient:
    """Return a ``TestClient`` bound to the producer FastAPI app."""
    from app.main import app
    return TestClient(app)


class TestHealthEndpoint:
    def test_health_returns_200(self, client: TestClient) -> None:
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json() == {"status": "healthy"}


class TestPayloadValidation:
    """Pydantic validation — these don't hit AWS at all."""

    def test_missing_data_field(self, client: TestClient) -> None:
        resp = client.post("/messages", json={"token": "x"})
        assert resp.status_code == 422

    def test_missing_token_field(self, client: TestClient) -> None:
        resp = client.post(
            "/messages",
            json={"data": {"email_subject": "a", "email_sender": "b",
                           "email_timestream": "c", "email_content": "d"}},
        )
        assert resp.status_code == 422

    def test_empty_email_subject_rejected(self, client: TestClient) -> None:
        payload = _make_payload()
        payload["data"]["email_subject"] = ""
        resp = client.post("/messages", json=payload)
        assert resp.status_code == 422

    def test_missing_email_content_rejected(self, client: TestClient) -> None:
        payload = _make_payload()
        del payload["data"]["email_content"]
        resp = client.post("/messages", json=payload)
        assert resp.status_code == 422

    def test_extra_fields_are_ignored(self, client: TestClient) -> None:
        """Pydantic v2 ignores extra fields by default."""
        payload = _make_payload()
        payload["data"]["extra_field"] = "should be ignored"
        with patch("app.main._fetch_token_from_ssm", new_callable=AsyncMock, return_value=VALID_TOKEN):
            with patch("app.main.publish_message_to_sqs", new_callable=AsyncMock) as mock_publish:
                resp = client.post("/messages", json=payload)
        assert resp.status_code == 202
        mock_publish.assert_awaited_once()


class TestTokenValidation:
    def test_invalid_token_returns_401(self, client: TestClient) -> None:
        with patch("app.main._fetch_token_from_ssm", new_callable=AsyncMock, return_value=VALID_TOKEN):
            resp = client.post("/messages", json=_make_payload(token="wrong"))
        assert resp.status_code == 401
        assert "Invalid" in resp.json()["detail"]


class TestSQSIntegration:
    def test_valid_message_accepted(self, client: TestClient) -> None:
        with patch("app.main._fetch_token_from_ssm", new_callable=AsyncMock, return_value=VALID_TOKEN):
            with patch("app.main.publish_message_to_sqs", new_callable=AsyncMock) as mock_publish:
                resp = client.post("/messages", json=_make_payload())

        assert resp.status_code == 202
        body = resp.json()
        assert body["status"] == "accepted"
        mock_publish.assert_awaited_once()

    def test_sqs_message_body_is_correct(self, client: TestClient) -> None:
        with patch("app.main._fetch_token_from_ssm", new_callable=AsyncMock, return_value=VALID_TOKEN):
            with patch("app.main.publish_message_to_sqs", new_callable=AsyncMock) as mock_publish:
                client.post("/messages", json=_make_payload())

        assert mock_publish.await_args is not None
        message_body = mock_publish.await_args.args[0]
        assert message_body["email_subject"] == "Hello"
        assert message_body["email_sender"] == "alice@example.com"
        assert "token" not in message_body
