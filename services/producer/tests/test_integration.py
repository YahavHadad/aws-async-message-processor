"""Integration tests for the Producer service.

These run against the actual Docker container (started by CI).
The container has no real AWS access, so we can only test:
  - health endpoint
  - Pydantic payload validation (which is pure application logic)
  - OpenAPI docs availability

Requires: ``INTEGRATION_TEST_URL`` env var (defaults to ``http://localhost:8000``).
"""

import os
from collections.abc import Iterator
from typing import Any

import httpx
import pytest

BASE_URL: str = os.getenv("INTEGRATION_TEST_URL", "http://localhost:8000")


@pytest.fixture(scope="module")
def client() -> Iterator[httpx.Client]:
    """Yield an ``httpx.Client`` pointed at the running container."""
    with httpx.Client(base_url=BASE_URL, timeout=10) as c:
        yield c


def _valid_payload(token: str = "some-token") -> dict[str, Any]:
    """Return a structurally valid request payload."""
    return {
        "data": {
            "email_subject": "Hello",
            "email_sender": "alice@example.com",
            "email_timestream": "1693561101",
            "email_content": "Integration test content",
        },
        "token": token,
    }


class TestHealth:
    def test_returns_200(self, client: httpx.Client) -> None:
        resp = client.get("/health")
        assert resp.status_code == 200

    def test_body_is_healthy(self, client: httpx.Client) -> None:
        resp = client.get("/health")
        assert resp.json() == {"status": "healthy"}


class TestOpenAPIDocs:
    def test_docs_available(self, client: httpx.Client) -> None:
        resp = client.get("/docs")
        assert resp.status_code == 200
        assert "html" in resp.headers.get("content-type", "").lower()

    def test_openapi_json_available(self, client: httpx.Client) -> None:
        resp = client.get("/openapi.json")
        assert resp.status_code == 200
        assert "paths" in resp.json()


class TestPayloadValidation:
    def test_empty_body_returns_422(self, client: httpx.Client) -> None:
        resp = client.post("/messages", json={})
        assert resp.status_code == 422

    def test_missing_data_field_returns_422(self, client: httpx.Client) -> None:
        resp = client.post("/messages", json={"token": "x"})
        assert resp.status_code == 422

    def test_missing_token_field_returns_422(self, client: httpx.Client) -> None:
        resp = client.post("/messages", json={
            "data": {
                "email_subject": "a",
                "email_sender": "b",
                "email_timestream": "c",
                "email_content": "d",
            }
        })
        assert resp.status_code == 422

    def test_incomplete_data_returns_422(self, client: httpx.Client) -> None:
        resp = client.post("/messages", json={
            "data": {"email_subject": "only one field"},
            "token": "t",
        })
        assert resp.status_code == 422

    def test_empty_email_subject_returns_422(self, client: httpx.Client) -> None:
        payload = _valid_payload()
        payload["data"]["email_subject"] = ""
        resp = client.post("/messages", json=payload)
        assert resp.status_code == 422

    def test_valid_shape_passes_validation(self, client: httpx.Client) -> None:
        """A structurally valid payload should not get 422.

        Without AWS access it will fail at token fetch (500) — that's expected.
        """
        resp = client.post("/messages", json=_valid_payload())
        assert resp.status_code != 422


class TestEdgeCases:
    def test_wrong_http_method_on_messages(self, client: httpx.Client) -> None:
        resp = client.get("/messages")
        assert resp.status_code == 405

    def test_invalid_json_returns_422(self, client: httpx.Client) -> None:
        resp = client.post(
            "/messages",
            content=b"not json",
            headers={"Content-Type": "application/json"},
        )
        assert resp.status_code == 422

    def test_nonexistent_route_returns_404(self, client: httpx.Client) -> None:
        resp = client.get("/does-not-exist")
        assert resp.status_code == 404
