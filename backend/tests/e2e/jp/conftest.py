"""pytest conftest for tests/e2e/jp/ — JP persona E2E tests.

Shared fixtures:
  - base_url: JP_STAGING_URL env var, defaults to http://localhost:8000
  - async_client: httpx.AsyncClient configured for the staging server
  - org_ids: well-known org IDs seeded by seed_jp_launch.py

These tests require a running JP backend (region=jp) and are intentionally
excluded from unit test runs via the @pytest.mark.e2e marker.

To run:
    JP_STAGING_URL=http://staging.ancu365.jp pytest tests/e2e/jp/ -m e2e -v

To skip in unit runs:
    pytest tests/ -m "not e2e"
"""

from __future__ import annotations

import os
from typing import AsyncGenerator

import httpx
import pytest
import pytest_asyncio


def pytest_configure(config: pytest.Config) -> None:
    """Register custom marks so pytest doesn't warn about unknown markers."""
    config.addinivalue_line(
        "markers",
        "e2e: end-to-end persona tests that require a running staging server",
    )


@pytest.fixture(scope="session")
def base_url() -> str:
    """Base URL for the JP staging server.

    Reads JP_STAGING_URL env var; defaults to http://localhost:8000.
    """
    return os.environ.get("JP_STAGING_URL", "http://localhost:8000")


@pytest.fixture(scope="session")
def org_ids() -> dict[str, str]:
    """Well-known org IDs seeded by seed_jp_launch.py."""
    return {
        "shinjuku": "org-shinjuku-001",
        "shibuya": "org-shibuya-002",
        "setagaya": "org-setagaya-003",
    }


@pytest.fixture(scope="session")
def headers_jp() -> dict[str, str]:
    """Common headers for all JP API calls."""
    return {
        "Content-Type": "application/json",
        "Accept": "application/json",
    }


@pytest_asyncio.fixture
async def client(base_url: str, headers_jp: dict[str, str]) -> AsyncGenerator[httpx.AsyncClient, None]:
    """Session-scoped httpx.AsyncClient for E2E calls.

    Timeout: 30s per request. Follows redirects.
    """
    async with httpx.AsyncClient(
        base_url=base_url,
        headers=headers_jp,
        timeout=30.0,
        follow_redirects=True,
    ) as c:
        yield c


@pytest.fixture(scope="session")
def owner_credentials() -> dict[str, str]:
    """Credentials for the owner persona (seeded staging account)."""
    return {
        "email": os.environ.get("E2E_OWNER_EMAIL", "owner@shinjuku-realty.jp"),
        "password": os.environ.get("E2E_OWNER_PASSWORD", "StagePass2026!"),
    }


@pytest.fixture(scope="session")
def broker_credentials() -> dict[str, str]:
    """Credentials for the broker persona (seeded staging account)."""
    return {
        "email": os.environ.get("E2E_BROKER_EMAIL", "broker@shibuya-homes.jp"),
        "password": os.environ.get("E2E_BROKER_PASSWORD", "StagePass2026!"),
    }


@pytest.fixture(scope="session")
def tenant_credentials() -> dict[str, str]:
    """Credentials for the tenant persona (seeded staging account)."""
    return {
        "email": os.environ.get("E2E_TENANT_EMAIL", "tenant@example.jp"),
        "password": os.environ.get("E2E_TENANT_PASSWORD", "StagePass2026!"),
    }


@pytest.fixture(scope="session")
def admin_credentials() -> dict[str, str]:
    """Credentials for the admin persona (seeded staging account)."""
    return {
        "email": os.environ.get("E2E_ADMIN_EMAIL", "admin@ancu365.jp"),
        "password": os.environ.get("E2E_ADMIN_PASSWORD", "StagePass2026!"),
    }
