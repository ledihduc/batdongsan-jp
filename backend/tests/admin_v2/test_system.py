"""Hệ thống: sức khoẻ theo mục, push/job, cờ (không secret), nhật ký hợp nhất,
sự kiện realtime (fallback + SSE)."""

from __future__ import annotations

import json
import re
from datetime import datetime

from sqlalchemy.orm import Session

from app import models
from app.api.routes.admin_v2 import system as sysroute
from tests.admin_v2.conftest import w


def test_health_sections_each_have_status(client, db, staff, tmp_path, monkeypatch):
    _, h = staff("SUPER_ADMIN")
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")
    lines = [
        {"ts": now, "event": "unhandled_exception", "fingerprint": "fp1", "exc_type": "KeyError", "path": "/api/x"},
        {"ts": now, "event": "unhandled_exception", "fingerprint": "fp1", "exc_type": "KeyError", "path": "/api/x"},
        {"ts": "2020-01-01T00:00:00.000Z", "event": "unhandled_exception", "fingerprint": "old"},
        {"ts": now, "event": "client_error", "fingerprint": "c1", "error_code": "TypeError", "route": "/home"},
    ]
    (tmp_path / "app.jsonl").write_text("không phải json\n" + "\n".join(json.dumps(x) for x in lines) + "\n")
    monkeypatch.setattr(sysroute.settings, "log_dir", str(tmp_path))
    db.add(models.PushOutbox(user_id=1, title="t", body="b", loai="x", khoa_gom="k1", so_lan_thu=4, loi_cuoi="FCM 503"))
    db.commit()
    r = client.get("/api/v2/admin/system/health", headers=h)
    assert r.status_code == 200, r.text
    s = r.json()["data"]["sections"]
    for name in ("database", "migrations", "storage", "push_outbox", "media_jobs", "server_errors",
                 "client_errors", "notification_providers"):
        assert s[name]["status"] in ("ok", "warn", "error", "unknown"), name
    assert s["database"]["status"] in ("ok", "warn") and s["database"]["latency_ms"] >= 0
    assert s["push_outbox"]["failed"] >= 1 and s["push_outbox"]["status"] == "warn"
    assert s["server_errors"]["count_24h"] == 2 and s["server_errors"]["top"][0]["fingerprint"] == "fp1"
    assert s["client_errors"]["count_24h"] == 1
    assert set(s["notification_providers"]["providers"]) == {"email", "sms", "push", "digital_signature"}
    assert "jwt" not in r.text.lower()


def test_flags_are_read_only_and_contain_no_secrets(client, staff):
    _, h = staff("SUPER_ADMIN")
    r = client.get("/api/v2/admin/system/flags", headers=h)
    assert r.status_code == 200
    flags = r.json()["data"]
    keys = {f["key"] for f in flags}
    assert "reels_enabled" in keys and "private_uploads_enforced" in keys and "notification_sms_provider" in keys
    bad = re.compile(r"secret|token|password|api_key|bank|account|salt|jwt|chat_id|credential|url|path")
    assert not [k for k in keys if bad.search(k)]
    assert all(f["type"] in ("boolean", "provider") for f in flags)
    assert all(isinstance(f["value"], bool) for f in flags if f["type"] == "boolean")
    _, hm = staff("MODERATOR")
    assert client.get("/api/v2/admin/system/flags", headers=hm).status_code == 403


def test_push_retry_resets_attempts(client, db, staff, user):
    _, h = staff("SUPER_ADMIN")
    u = user()
    p = models.PushOutbox(user_id=u.id, title="Cọc đã xác minh", body="b", loai="coc", khoa_gom="k-retry",
                          so_lan_thu=5, loi_cuoi="token hỏng")
    db.add(p)
    db.commit()
    rows = client.get("/api/v2/admin/system/notifications?state=failed", headers=h).json()["data"]
    row = next(x for x in rows if x["id"] == p.id)
    assert row["exhausted"] is True and row["retryable"] is True and row["user"]["id"] == u.id
    r = client.post(f"/api/v2/admin/system/notifications/{p.id}/retry", headers=w(h, row["version"]),
                    json={"reason": "đã sửa cấu hình FCM"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["state"] == "queued" and r.json()["data"]["attempts"] == 0
    _, hs = staff("COMPLIANCE")  # không có settings.manage
    assert client.post(f"/api/v2/admin/system/notifications/{p.id}/retry", headers=w(hs, "x"),
                       json={"reason": "thử lại"}).status_code == 403


def test_audit_explorer_merges_sources(client, db, staff, user):
    a, h = staff("AUDITOR")
    actor = user()
    db.add(models.AdminActionLog(actor_user_id=actor.id, action="kyc.approve", entity_type="kyc", entity_id="7",
                                 reason="đủ hồ sơ", result="success"))
    db.add(models.ChangeLog(entity_type="contract", entity_id=5, actor_id=actor.id, action="update",
                            before_json=json.dumps({"rent": 1}), after_json=json.dumps({"rent": 2, "cccd": "012345678901"})))
    db.add(models.AuditLog(host_id=actor.id, action="export_tt200", period="2026-09", success=True))
    db.add(models.ActivityAuditEvent(actor_user_id=actor.id, action="viewing.confirm", idempotency_key="k" * 10,
                                     target_type="viewing", target_id=3, payload={"x": 1}))
    db.commit()
    r = client.get(f"/api/v2/admin/audit-events?actor_id={actor.id}", headers=h)
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    assert {x["source"] for x in data} == {"admin", "legacy", "change", "activity"}
    ch = next(x for x in data if x["source"] == "change")
    assert ch["id"].startswith("change:") and ch["before"] == {"rent": 1}
    assert "012345678901" not in r.text  # PII trong nhật ký cũ bị che
    assert r.json()["meta"]["total"] == 4 and r.json()["meta"]["truncated"] is False
    r = client.get(f"/api/v2/admin/audit-events?actor_id={actor.id}&source=change,admin&action=kyc.", headers=h)
    assert [x["source"] for x in r.json()["data"]] == ["admin"]
    r = client.get(f"/api/v2/admin/audit-events?entity_type=contract&entity_id=5", headers=h)
    assert {x["source"] for x in r.json()["data"]} == {"change"}
    _, hm = staff("MODERATOR")
    assert client.get("/api/v2/admin/audit-events", headers=hm).status_code == 403


def test_events_fallback_returns_events_after_cursor(client, db, staff):
    _, h = staff("ANALYST")
    for i in range(3):
        db.add(models.AdminEvent(event_type="admin.test", entity_type="x", entity_id=str(i), status="ok"))
    db.commit()
    r = client.get("/api/v2/admin/events", headers=h)
    assert r.status_code == 200
    ids = [e["id"] for e in r.json()["data"]]
    assert ids == sorted(ids) and len(ids) >= 3
    first = ids[-3]
    r = client.get(f"/api/v2/admin/events?after={first}", headers=h)
    got = r.json()["data"]
    assert [e["id"] for e in got] == ids[-2:]
    assert set(got[0]) == {"id", "event_type", "entity_type", "entity_id", "status", "created_at"}
    assert r.json()["meta"]["next_after"] == ids[-1] and r.json()["meta"]["has_more"] is False


def test_sse_stream_delivers_events_and_closes(client, db, staff, monkeypatch):
    _, h = staff("ANALYST")
    conn = db.get_bind()
    monkeypatch.setattr(sysroute, "session_factory", lambda: Session(bind=conn))
    monkeypatch.setattr(sysroute, "STREAM_POLL_SECONDS", 0.05)
    monkeypatch.setattr(sysroute, "STREAM_MAX_SECONDS", 0.3)
    db.add(models.AdminEvent(event_type="admin.kyc.approve", entity_type="kyc", entity_id="1", status="verified"))
    db.commit()
    last = db.query(models.AdminEvent).order_by(models.AdminEvent.id.desc()).first().id
    with client.stream("GET", f"/api/v2/admin/events/stream?after={last - 1}", headers=h) as r:
        assert r.status_code == 200
        assert r.headers["content-type"].startswith("text/event-stream")
        body = "".join(r.iter_text())
    assert f"id: {last}" in body and "event: admin_event" in body and "event: reconnect" in body
    payload = json.loads(next(ln for ln in body.splitlines() if ln.startswith("data: {\"id\"")) [6:])
    assert set(payload) == {"id", "event_type", "entity_type", "entity_id", "status", "created_at"}
    # Last-Event-ID cũng là cursor.
    with client.stream("GET", "/api/v2/admin/events/stream", headers={**h, "Last-Event-ID": str(last)}) as r:
        body = "".join(r.iter_text())
    assert f"id: {last}\n" not in body
