import os

import pytest


@pytest.fixture(autouse=True)
def _force_app_test_mode() -> None:
    # Ensures the consumer never attempts real AWS calls during unit tests.
    os.environ["APP_TEST_MODE"] = "1"
