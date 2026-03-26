"""Centralised logging configuration for producer and consumer."""

from __future__ import annotations

import logging
import sys

_configured_for: str | None = None


class ServiceContextFilter(logging.Filter):
    """Injects ``service`` on every log record for the formatter."""

    def __init__(self, service_name: str) -> None:
        super().__init__()
        self._service_name = service_name

    def filter(self, record: logging.LogRecord) -> bool:
        record.service = self._service_name
        return True


def setup_logging(service_name: str, level: int = logging.INFO) -> None:
    """Configure the root logger once per process with a structured format.

    Adds service name, process id, and thread name to every line so logs
    from ECS/CloudWatch are easier to correlate.
    """
    global _configured_for
    if _configured_for == service_name:
        return

    log_format = (
        "%(asctime)s | %(levelname)-8s | service=%(service)s | "
        "pid=%(process)d | thread=%(threadName)s | %(name)s | %(message)s"
    )
    formatter = logging.Formatter(log_format, datefmt="%Y-%m-%d %H:%M:%S")

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    handler.addFilter(ServiceContextFilter(service_name))

    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)
    root.addHandler(handler)

    _configured_for = service_name
