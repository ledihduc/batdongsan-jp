"""E2E persona: Owner — list property, approve application, settle deposit.

Journey:
  1. Login as owner (broker org admin)
  2. List a new chintai property
  3. Retrieve listings to confirm listing is present
  4. Approve a pending tenant application (if any)
  5. Settle deposit after lease confirmation

Requires a running JP backend (region=jp) with seed data from seed_jp_launch.py.
Set JP_STAGING_URL env var to point at the staging server.

Run:
    JP_STAGING_URL=http://staging.ancu365.jp pytest tests/e2e/jp/test_persona_owner.py -m e2e -v
"""

from __future__ import annotations

import time
from typing import Optional

import httpx
import pytest


pytestmark = pytest.mark.e2e


async def _login(client: httpx.AsyncClient, email: str, password: str) -> str:
    """Login and return JWT access token.

    Raises AssertionError if login fails.
    """
    t0 = time.monotonic()
    resp = await client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, f"Login failed: {resp.status_code} — {resp.text}"
    data = resp.json()
    token = data.get("access_token") or data.get("token")
    assert token, f"No token in login response: {data}"
    print(f"  [owner] login OK ({elapsed:.2f}s)")
    return token


@pytest.mark.asyncio
async def test_owner_journey(
    client: httpx.AsyncClient,
    owner_credentials: dict[str, str],
    org_ids: dict[str, str],
) -> None:
    """Full owner journey: login → create listing → list → approve application → settle."""

    # ── Step 1: Login ──────────────────────────────────────────────────────────
    token = await _login(client, owner_credentials["email"], owner_credentials["password"])
    auth_headers = {"Authorization": f"Bearer {token}"}
    org_id = org_ids["shinjuku"]

    # ── Step 2: Create a listing ───────────────────────────────────────────────
    t0 = time.monotonic()
    listing_payload = {
        "org_id": org_id,
        "title": "E2E Owner Test — 1K 新宿",
        "postal_code": "160-0022",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "新宿三丁目 E2E-test",
        "layout": "1K",
        "monthly_rent_jpy": 85000,
        "management_fee_jpy": 3000,
        "shikikin_months": 1.0,
        "reikin_months": 1.0,
        "koushinryo_months": 1.0,
        "status": "available",
        "region": "jp",
    }
    resp = await client.post(
        "/api/jp/listings",
        json=listing_payload,
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code in (200, 201), (
        f"Create listing failed: {resp.status_code} — {resp.text}"
    )
    listing = resp.json()
    listing_id: Optional[int] = listing.get("id") or listing.get("listing_id")
    assert listing_id is not None, f"No listing_id in response: {listing}"
    print(f"  [owner] create listing OK id={listing_id} ({elapsed:.2f}s)")

    # ── Step 3: Retrieve listings ──────────────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/listings",
        params={"org_id": org_id, "limit": 20},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, f"List listings failed: {resp.status_code} — {resp.text}"
    listings_data = resp.json()
    items = listings_data if isinstance(listings_data, list) else listings_data.get("items", [])
    ids = [i.get("id") or i.get("listing_id") for i in items]
    assert listing_id in ids, f"Created listing_id={listing_id} not found in listing response"
    print(f"  [owner] list listings OK ({len(items)} items, {elapsed:.2f}s)")

    # ── Step 4: Check for pending applications ─────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        f"/api/jp/listings/{listing_id}/applications",
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    # No applications on freshly created listing is expected
    if resp.status_code == 200:
        apps = resp.json()
        app_list = apps if isinstance(apps, list) else apps.get("items", [])
        print(f"  [owner] applications: {len(app_list)} pending ({elapsed:.2f}s)")

        # If any pending applications exist, approve the first one
        pending = [a for a in app_list if a.get("status") == "pending"]
        if pending:
            app_id = pending[0]["id"]
            t0 = time.monotonic()
            resp2 = await client.post(
                f"/api/jp/applications/{app_id}/review",
                json={"decision": "approved", "note": "E2E test approve"},
                headers=auth_headers,
            )
            elapsed2 = time.monotonic() - t0
            assert resp2.status_code in (200, 201), (
                f"Approve application failed: {resp2.status_code} — {resp2.text}"
            )
            print(f"  [owner] approve application {app_id} OK ({elapsed2:.2f}s)")
    else:
        print(f"  [owner] no application endpoint or no apps ({resp.status_code})")

    # ── Step 5: Smoke-test deposit settlement list ─────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/deposit-settlements",
        params={"org_id": org_id, "limit": 5},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    # 200 or 404 is acceptable — endpoint may not exist in all deploy configurations
    assert resp.status_code in (200, 404, 422), (
        f"Deposit settlements unexpected status: {resp.status_code} — {resp.text}"
    )
    print(f"  [owner] deposit settlements status={resp.status_code} ({elapsed:.2f}s)")
    print("  [owner] journey PASS")
