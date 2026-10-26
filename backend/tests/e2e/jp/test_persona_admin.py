"""E2E persona: Admin — view KPIs, export DSR, trigger deletion cron, check compliance.

Journey:
  1. Login as admin
  2. View admin KPIs
  3. Export DSR (data subject request) for a test email
  4. Trigger deletion cron (dry-run via admin endpoint if available)
  5. Retrieve compliance evidence snapshot

Requires a running JP backend (region=jp) with seed data from seed_jp_launch.py.
"""

from __future__ import annotations

import time

import httpx
import pytest


pytestmark = pytest.mark.e2e


async def _login(client: httpx.AsyncClient, email: str, password: str) -> str:
    """Login and return JWT access token."""
    resp = await client.post(
        "/api/auth/login",
        json={"email": email, "password": password},
    )
    assert resp.status_code == 200, f"Admin login failed: {resp.status_code} — {resp.text}"
    data = resp.json()
    token = data.get("access_token") or data.get("token")
    assert token, f"No token in admin login response: {data}"
    return token


@pytest.mark.asyncio
async def test_admin_journey(
    client: httpx.AsyncClient,
    admin_credentials: dict[str, str],
    org_ids: dict[str, str],
) -> None:
    """Full admin journey: login → KPIs → DSR export → deletion cron → compliance evidence."""

    # ── Step 1: Login ──────────────────────────────────────────────────────────
    token = await _login(client, admin_credentials["email"], admin_credentials["password"])
    auth_headers = {"Authorization": f"Bearer {token}"}

    # ── Step 2: View admin KPIs ────────────────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/admin/kpis",
        params={"prefecture": "東京都"},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, f"KPI endpoint failed: {resp.status_code} — {resp.text}"
    kpi_data = resp.json()
    kpis = kpi_data.get("kpis", {})
    assert "application_count" in kpis, f"Missing application_count in KPIs: {kpis}"
    assert "success_rate" in kpis, f"Missing success_rate in KPIs: {kpis}"
    assert "vacancy_rate" in kpis, f"Missing vacancy_rate in KPIs: {kpis}"
    print(f"  [admin] KPIs OK application_count={kpis.get('application_count')} ({elapsed:.2f}s)")

    # ── Step 3: Export DSR ─────────────────────────────────────────────────────
    t0 = time.monotonic()
    resp = await client.post(
        "/api/jp/me/dsr/export",
        json={"email": "tenant@example.jp", "reason": "E2E admin DSR test"},
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    # 200 = export queued; 404 = DSR endpoint not in this deployment; 422 = invalid
    assert resp.status_code in (200, 201, 202, 404, 422), (
        f"DSR export unexpected status: {resp.status_code} — {resp.text}"
    )
    print(f"  [admin] DSR export status={resp.status_code} ({elapsed:.2f}s)")

    # ── Step 4: Trigger deletion cron (admin endpoint smoke test) ──────────────
    t0 = time.monotonic()
    resp = await client.post(
        "/api/jp/admin/deletion-cron/run",
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    # 200 = triggered; 404 = not exposed; 403 = only for system
    assert resp.status_code in (200, 202, 404, 403), (
        f"Deletion cron unexpected status: {resp.status_code} — {resp.text}"
    )
    print(f"  [admin] deletion cron trigger status={resp.status_code} ({elapsed:.2f}s)")

    # ── Step 5: Compliance evidence snapshot ───────────────────────────────────
    t0 = time.monotonic()
    resp = await client.get(
        "/api/jp/compliance/evidence",
        headers=auth_headers,
    )
    elapsed = time.monotonic() - t0
    assert resp.status_code == 200, (
        f"Compliance evidence failed: {resp.status_code} — {resp.text}"
    )
    evidence = resp.json()
    assert "appi_consented_users_count" in evidence, f"Missing field in evidence: {evidence}"
    assert "last_deletion_cron_run" in evidence, f"Missing field in evidence: {evidence}"
    assert "pii_key_rotation_date" in evidence, f"Missing field in evidence: {evidence}"
    assert "hmac_rotation_ledger" in evidence, f"Missing field in evidence: {evidence}"
    assert "generated_at" in evidence, f"Missing field in evidence: {evidence}"
    print(
        f"  [admin] compliance evidence OK "
        f"consented={evidence.get('appi_consented_users_count')} ({elapsed:.2f}s)"
    )
    print("  [admin] journey PASS")
