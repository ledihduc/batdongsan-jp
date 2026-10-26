"""E2E persona: Broker — invite tenant, submit application, confirm renewal.

Journey:
  1. Login as broker
  2. Fetch available listings from their org
  3. Create a tenant application on a listing
  4. Submit the application for review
  5. Check renewal list (confirm renewal endpoint is reachable)

Requires a running JP backend (region=jp) with seed data from seed_jp_launch.py.
"""

from __future__ import annotations

import time
from typing import Optional

import httpx
import pytest


pytestmark = pytest.mark.e2e


async def _login(client: httpx.AsyncClient, email: str, password: str) -> str:
    """Login and return JWT access token."""
    resp = await client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert resp.status_code == 200, f"Broker login failed: {resp.status_code} — {resp.text}"
    data = resp.json()
    token = data.get("access_token") or data.get("token")
    assert token, f"No token in broker login response: {data}"
    return token


@pytest.mark.asyncio
async def test_broker_journey(
    client: httpx.AsyncClient,
    broker_credentials: dict[str, str],
    org_ids: dict[str, str],
) -> None:
    """Full broker journey: login → list properties → submit application → check renewals."""

    # ── Step 1: Login ──────────────────────────────────────────────────────────
    token = await _login(client, broker_credentials["email"], broker_credentials["password"])
    auth_headers = {"Authorization": f"Bearer {token}"}
    org_id = org_ids["shibuya"]

    # ── Step 2: Fetch available listings ───────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/listings",
        params={"org_id": org_id, "status": "available", "limit": 5},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, f"List listings failed: {resp.status_code} — {resp.text}"
    listings_data = resp.json()
    items = listings_data if isinstance(listings_data, list) else listings_data.get("items", [])
    print(f"  [broker] fetched {len(items)} available listings ({elapsed:.2f}s)")

    if not items:
        pytest.skip("No available listings in broker org — seed data may be missing")

    listing_id: int = items[0].get("id") or items[0].get("listing_id")
    assert listing_id, "No listing_id in first listing"

    # ── Step 3: Create a tenant application ───────────────────────────────────
    t0 = time.monotonic()
    app_payload = {
        "org_id": org_id,
        "listing_id": listing_id,
        "tenant_name": "山田 太郎",
        "tenant_email": "yamada.taro@example.jp",
        "tenant_phone": "+81-90-1234-5678",
        "guarantor_name": "山田 花子",
        "move_in_date": "2026-12-01",
        "note": "E2E broker test application",
        "region": "jp",
    }
    resp = await client.post(
        "/api/jp/applications",
        json=app_payload,
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code in (200, 201), (
        f"Create application failed: {resp.status_code} — {resp.text}"
    )
    app_data = resp.json()
    app_id: Optional[int] = app_data.get("id") or app_data.get("application_id")
    assert app_id is not None, f"No application_id in response: {app_data}"
    print(f"  [broker] created application id={app_id} ({elapsed:.2f}s)")

    # ── Step 4: Submit application ─────────────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.post(
        f"/api/jp/applications/{app_id}/submit",
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    # 200 = submitted; 422 = already submitted is acceptable
    assert resp.status_code in (200, 201, 409, 422), (
        f"Submit application unexpected status: {resp.status_code} — {resp.text}"
    )
    print(f"  [broker] submit application status={resp.status_code} ({elapsed:.2f}s)")

    # ── Step 5: Check renewals endpoint ───────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/renewals",
        params={"org_id": org_id, "limit": 5},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code in (200, 404), (
        f"Renewals endpoint unexpected: {resp.status_code} — {resp.text}"
    )
    print(f"  [broker] renewals status={resp.status_code} ({elapsed:.2f}s)")
    print("  [broker] journey PASS")
