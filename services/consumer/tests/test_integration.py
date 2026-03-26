"""Integration tests for the Consumer service.

These run against the actual Docker container (started by CI).
The consumer has no HTTP endpoint - it is a background SQS poller.

In CI we run with ``APP_TEST_MODE=1``, so the process must stay healthy
without creating AWS clients or making outbound AWS calls.

We validate via ``docker inspect`` and ``docker logs``.

Requires: ``INTEGRATION_CONTAINER`` env var (defaults to ``consumer-integration-test``).
"""

import os
import subprocess

import pytest

CONTAINER: str = os.getenv("INTEGRATION_CONTAINER", "consumer-integration-test")


def _docker(*args: str) -> subprocess.CompletedProcess[str]:
    """Run a ``docker`` CLI command and return the completed process."""
    return subprocess.run(
        ["docker", *args],
        capture_output=True,
        text=True,
        timeout=15,
    )


def _is_running() -> bool:
    """Return ``True`` if the integration-test container is still running."""
    result = _docker("inspect", CONTAINER, "--format", "{{.State.Running}}")
    return result.stdout.strip() == "true"


def _get_logs() -> str:
    """Return combined stdout + stderr from the container."""
    result = _docker("logs", CONTAINER)
    return result.stdout + result.stderr


class TestContainerLifecycle:
    def test_container_is_running(self) -> None:
        assert _is_running(), "Container should still be running"

    def test_exit_code_is_not_set(self) -> None:
        result = _docker("inspect", CONTAINER, "--format", "{{.State.ExitCode}}")
        assert result.stdout.strip() == "0", "Container should not have exited with an error"


class TestStartupBehavior:
    def test_logs_contain_startup_message(self) -> None:
        logs = _get_logs()
        assert "Consumer started" in logs, (
            f"Expected 'Consumer started' in logs, got:\n{logs[:500]}"
        )

    def test_logs_show_app_test_mode(self) -> None:
        logs = _get_logs()
        assert "APP_TEST_MODE enabled" in logs and "no AWS clients will be created" in logs, (
            "Logs should confirm AWS calls are disabled in integration mode"
        )


class TestErrorResilience:
    def test_container_survives_sqs_errors(self) -> None:
        """In APP_TEST_MODE the consumer should keep running without AWS access."""
        assert _is_running(), "Container should survive SQS connection failures"

    def test_logs_do_not_show_aws_error_loop(self) -> None:
        logs = _get_logs()
        assert "backing off" not in logs.lower(), (
            "APP_TEST_MODE should bypass live AWS polling/backoff loop"
        )

    def test_container_did_not_exit(self) -> None:
        """The container should still be running — no unhandled crash."""
        result = _docker("inspect", CONTAINER, "--format", "{{.State.Status}}")
        assert result.stdout.strip() == "running", (
            f"Container status should be 'running', got: {result.stdout.strip()}"
        )
