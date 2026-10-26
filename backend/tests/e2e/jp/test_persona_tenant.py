"""E2E persona: Tenant — browse, apply, sign contract, review settlement.

Journey:
  1. Login as tenant
  2. Browse available listings (public listings API)
  3. Apply to a listing
  4. Check application status
  5. Review deposit settlement (smoke test — may be empty)

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
    assert resp.status_code == 200, f"Tenant login failed: {resp.status_code} — {resp.text}"
    data = resp.json()
    token = data.get("access_token") or data.get("token")
    assert token, f"No token in tenant login response: {data}"
    return token


@pytest.mark.asyncio
async def test_tenant_journey(
    client: httpx.AsyncClient,
    tenant_credentials: dict[str, str],
    org_ids: dict[str, str],
) -> None:
    """Full tenant journey: login → browse → apply → check status → settlement."""

    # ── Step 1: Login ──────────────────────────────────────────────────────────
    token = await _login(client, tenant_credentials["email"], tenant_credentials["password"])
    auth_headers = {"Authorization": f"Bearer {token}"}

    # ── Step 2: Browse available listings (any org) ────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/listings",
        params={"status": "available", "limit": 10},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, f"Browse listings failed: {resp.status_code} — {resp.text}"
    listings_data = resp.json()
    items = listings_data if isinstance(listings_data, list) else listings_data.get("items", [])
    print(f"  [tenant] browsed {len(items)} listings ({elapsed:.2f}s)")

    if not items:
        pytest.skip("No available listings — seed data may be missing")

    target = items[0]
    listing_id: int = target.get("id") or target.get("listing_id")
    org_id: str = target.get("org_id", org_ids["shinjuku"])
    assert listing_id, "No listing_id in first listing"

    # ── Step 3: Apply to listing ───────────────────────────────────────────────
    t0 = time.monotonic()
    app_payload = {
        "org_id": org_id,
        "listing_id": listing_id,
        "tenant_name": "鈴木 一郎",
        "tenant_email": tenant_credentials["email"],
        "tenant_phone": "+81-80-9876-5432",
        "guarantor_name": "鈴木 義雄",
        "move_in_date": "2026-12-15",
        "note": "E2E tenant test application",
        "region": "jp",
    }
    resp = await client.post(
        "/api/jp/applications",
        json=app_payload,
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code in (200, 201), (
        f"Apply to listing failed: {resp.status_code} — {resp.text}"
    )
    app_data = resp.json()
    app_id: Optional[int] = app_data.get("id") or app_data.get("application_id")
    assert app_id is not None, f"No application_id in response: {app_data}"
    print(f"  [tenant] applied app_id={app_id} ({elapsed:.2f}s)")

    # ── Step 4: Check application status ──────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        f"/api/jp/applications/{app_id}",
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, (
        f"Get application status failed: {resp.status_code} — {resp.text}"
    )
    status_data = resp.json()
    app_status = status_data.get("status")
    assert app_status is not None, f"No status in application response: {status_data}"
    print(f"  [tenant] application status={app_status} ({elapsed:.2f}s)")

    # ── Step 5: Smoke test deposit settlement ──────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/deposit-settlements",
        params={"limit": 5},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code in (200, 403, 404), (
        f"Settlement endpoint unexpected: {resp.status_code} — {resp.text}"
    )
    print(f"  [tenant] settlement endpoint status={resp.status_code} ({elapsed:.2f}s)")
    print("  [tenant] journey PASS")
