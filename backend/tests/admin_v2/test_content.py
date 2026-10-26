"""Admin V2 — module Nội dung: tin đăng, báo cáo, Reel, thẩm định sao, đánh giá.

Chứng minh: ranh giới quyền, lý do bắt buộc, If-Match (409/428), replay
idempotent, trả trạng thái sau thao tác, chủ tin được báo, phân trang ở server.
Thêm hai test cho route CŨ đã chuyển sang gọi `content_ops` (hành vi giữ nguyên).
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app import models
from app.database import get_db
from tests.admin_v2.conftest import app_token, key, w

BASE = "/api/v2/admin"


def _house(db, host, **kw) -> models.House:
    h = models.House(
        host_id=host.id, title=kw.pop("title", "Căn hộ 2 phòng ngủ Quận 7"), category_id=kw.pop("category_id", 1),
        price=kw.pop("price", 8_000_000), status=kw.pop("status", "pending_review"), **kw,
    )
    db.add(h)
    db.commit()
    return h


def _version(client, h, house_id) -> str:
    r = client.get(f"{BASE}/listings/{house_id}", headers=h)
    assert r.status_code == 200, r.text
    return r.json()["data"]["version"]


# ── Tin đăng ─────────────────────────────────────────────────────────────────


def test_listing_list_is_paginated_filtered_and_masked(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user(name="Chủ tin", email="chutin@vidu.vn")
    ids = [_house(db, host, title=f"Phòng trọ số {i}").id for i in range(3)]
    _house(db, host, title="Tin đã đăng", status="published")
    r = client.get(f"{BASE}/listings?limit=2&host_id={host.id}", headers=h)
    body = r.json()
    assert r.status_code == 200, r.text
    assert body["meta"]["total"] == 3 and len(body["data"]) == 2 and body["meta"]["next_cursor"] == "2"
    row = body["data"][0]
    assert row["host"]["email_masked"].startswith("ch***@") and "email" not in row["host"]
    assert row["version"] and row["ref"].startswith("TIN-")
    r = client.get(f"{BASE}/listings?status=all&host_id={host.id}", headers=h)
    assert r.json()["meta"]["total"] == 4
    r = client.get(f"{BASE}/listings?status=all&q=TIN-{ids[1]:05d}", headers=h)
    assert [x["id"] for x in r.json()["data"]] == [ids[1]]
    assert client.get(f"{BASE}/listings?status=bogus", headers=h).status_code == 422


def test_finance_cannot_read_or_moderate_listings(client, db, staff, user):
    _, h = staff("FINANCE")
    house = _house(db, user())
    assert client.get(f"{BASE}/listings", headers=h).status_code == 403
    r = client.post(f"{BASE}/listings/{house.id}/moderation-decisions", headers=w(h, "x"),
                    json={"decision": "approve"})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_PERMISSION_DENIED"
    # SUPPORT đọc được nhưng không duyệt được.
    _, hs = staff("SUPPORT")
    assert client.get(f"{BASE}/listings/{house.id}", headers=hs).status_code == 200
    assert client.post(f"{BASE}/listings/{house.id}/moderation-decisions", headers=w(hs, "x"),
                       json={"decision": "approve"}).status_code == 403


def test_approve_notifies_host_returns_post_state_and_writes_logs(client, db, staff, user):
    mod, h = staff("MODERATOR")
    host = user()
    house = _house(db, host, images=["/uploads/a.jpg"], latitude=10.7, longitude=106.7)
    v = _version(client, h, house.id)
    r = client.post(f"{BASE}/listings/{house.id}/moderation-decisions", headers=w(h, v),
                    json={"decision": "approve", "reason": ""})
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    assert data["status"] == "published" and data["version"] != v
    assert db.query(models.Notification).filter_by(user_id=host.id, type="house_approved").count() == 1
    assert db.query(models.AuditLog).filter_by(host_id=host.id, action="house_approve").count() == 1
    log = db.query(models.AdminActionLog).filter_by(action="listing.approve", entity_id=str(house.id)).one()
    assert log.actor_user_id == mod.id and log.after_json["status"] == "published"
    detail = client.get(f"{BASE}/listings/{house.id}", headers=h).json()["data"]
    sources = {e["source"] for e in detail["timeline"]}
    assert {"admin_v2", "legacy_audit", "system"} <= sources
    assert detail["allowed_decisions"] == ["unpublish"]


def test_reject_needs_reason_if_match_and_replays_idempotently(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    house = _house(db, host)
    url = f"{BASE}/listings/{house.id}/moderation-decisions"
    v = _version(client, h, house.id)
    r = client.post(url, headers=w(h, v), json={"decision": "reject", "reason": ""})
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_REASON_REQUIRED"
    assert client.post(url, headers=w(h), json={"decision": "reject", "reason": "ảnh không thật"}).status_code == 428
    r = client.post(url, headers=w(h, "cu-roi"), json={"decision": "reject", "reason": "ảnh không thật"})
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_CONFLICT"
    hdr = {**h, "Idempotency-Key": key(), "If-Match": v}
    first = client.post(url, headers=hdr, json={"decision": "reject", "reason": "ảnh không thật"})
    again = client.post(url, headers=hdr, json={"decision": "reject", "reason": "ảnh không thật"})
    assert first.status_code == again.status_code == 200
    assert again.json()["meta"]["idempotent_replay"] is True
    assert first.json()["data"]["status"] == "rejected"
    assert first.json()["data"]["rejection_reason"] == "ảnh không thật"
    assert db.query(models.Notification).filter_by(user_id=host.id, type="house_rejected").count() == 1


def test_unpublish_only_from_published_and_hides(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    pending = _house(db, host)
    r = client.post(f"{BASE}/listings/{pending.id}/moderation-decisions",
                    headers=w(h, _version(client, h, pending.id)), json={"decision": "unpublish", "reason": "lừa đảo cọc"})
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_INVALID_TRANSITION"
    live = _house(db, host, status="published")
    r = client.post(f"{BASE}/listings/{live.id}/moderation-decisions",
                    headers=w(h, _version(client, h, live.id)), json={"decision": "unpublish", "reason": "lừa đảo cọc"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "hidden" and r.json()["data"]["rejection_reason"] == "lừa đảo cọc"
    assert db.query(models.Notification).filter_by(user_id=host.id, type="house_hidden").count() == 1


def test_detail_has_duplicates_checklist_and_owner_history(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    a = _house(db, host, title="Căn hộ cao cấp view sông Sài Gòn A", latitude=10.75, longitude=106.70,
               address="12 Nguyễn Huệ", price=9_000_000)
    b = _house(db, host, title="Căn hộ cao cấp view sông Sài Gòn B", status="published")
    c = _house(db, user(), title="Khác hẳn", latitude=10.75015, longitude=106.70010)
    _house(db, host, title="Bị từ chối trước", status="rejected")
    db.add(models.ContentReport(target_type="house", target_id=b.id, reporter_id=user().id, reason="scam"))
    db.commit()
    d = client.get(f"{BASE}/listings/{a.id}", headers=h).json()["data"]
    dups = {x["id"]: x["match"] for x in d["duplicates"]}
    assert "same_host_similar_title" in dups[b.id] and "same_location" in dups[c.id]
    checks = {x["code"]: x["ok"] for x in d["checklist"]}
    assert checks["images"] is False and checks["coordinates"] is True and checks["price"] is True
    v = d["owner"]["violations"]
    assert v["rejected_listings"] == 1 and v["content_reports_against"] == 1
    assert d["map"] == {"lat": 10.75, "lng": 106.70, "geocode_status": "pending"}


def test_trusted_toggle_requires_permission_and_version(client, db, staff, user):
    _, h = staff("MODERATOR")
    house = _house(db, user(), status="published")
    v = _version(client, h, house.id)
    r = client.post(f"{BASE}/listings/{house.id}/trusted", headers=w(h, v), json={"is_trusted": True})
    assert r.status_code == 200 and r.json()["data"]["is_trusted"] is True
    db.expire_all()
    assert db.get(models.House, house.id).trusted_by_admin_id is not None
    stale = client.post(f"{BASE}/listings/{house.id}/trusted", headers=w(h, v),
                        json={"is_trusted": False, "reason": "chủ tin vi phạm"})
    assert stale.status_code == 409
    _, hs = staff("SUPPORT")
    assert client.post(f"{BASE}/listings/{house.id}/trusted", headers=w(hs, v),
                       json={"is_trusted": False}).status_code == 403


# ── Báo cáo nội dung ─────────────────────────────────────────────────────────


def test_report_hide_house_unpublishes_listing(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    house = _house(db, host, status="published")
    rep = models.ContentReport(target_type="house", target_id=house.id, reporter_id=user().id, reason="scam")
    db.add(rep)
    db.commit()
    v = client.get(f"{BASE}/content-reports/{rep.id}", headers=h).json()["data"]["version"]
    r = client.post(f"{BASE}/content-reports/{rep.id}/decisions", headers=w(h, v),
                    json={"decision": "resolve_and_hide", "reason": "tin lừa đảo"})
    assert r.status_code == 200, r.text
    db.expire_all()
    assert db.get(models.House, house.id).status == "hidden"
    assert db.query(models.Notification).filter_by(user_id=host.id, type="house_hidden").count() == 1


# ── Thẩm định sao ────────────────────────────────────────────────────────────


def test_verification_complete_sets_house_star_and_notifies(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    house = _house(db, host, status="published")
    req = models.VerificationRequest(house_id=house.id, host_id=host.id, status="requested")
    db.add(req)
    db.commit()
    row = next(x for x in client.get(f"{BASE}/verifications", headers=h).json()["data"] if x["id"] == req.id)
    url = f"{BASE}/verifications/{req.id}/complete"
    assert client.post(url, headers=w(h, row["version"]), json={"verified_star": 6}).status_code == 422
    r = client.post(url, headers=w(h, row["version"]),
                    json={"verified_star": 4, "note": "Đạt PCCC", "criteria": {"pccc": True}})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "done" and r.json()["data"]["house"]["quality_verified_star"] == 4
    db.expire_all()
    assert db.get(models.House, house.id).quality_criteria == {"pccc": True}
    assert db.query(models.Notification).filter_by(user_id=host.id, type="verification_done").count() == 1
    rej = client.post(f"{BASE}/verifications/{req.id}/reject", headers=w(h, r.json()["data"]["version"]),
                      json={"reason": "thiếu ảnh hiện trạng"})
    assert rej.status_code == 409


def test_verification_reject_requires_reason(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    house = _house(db, host)
    req = models.VerificationRequest(house_id=house.id, host_id=host.id, status="inspecting")
    db.add(req)
    db.commit()
    v = client.get(f"{BASE}/verifications?status=inspecting", headers=h).json()["data"][0]["version"]
    url = f"{BASE}/verifications/{req.id}/reject"
    assert client.post(url, headers=w(h, v), json={"reason": ""}).status_code == 422
    r = client.post(url, headers=w(h, v), json={"reason": "không vào được nhà"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "rejected"
    assert r.json()["data"]["note"] == "không vào được nhà"


def test_reviews_list(client, db, staff, user):
    _, h = staff("MODERATOR")
    house = _house(db, user(), status="published")
    db.add(models.Review(user_id=user().id, house_id=house.id, rating=1, comment="Lừa đảo"))
    db.commit()
    r = client.get(f"{BASE}/reviews?max_rating=2&house_id={house.id}", headers=h)
    assert r.status_code == 200 and r.json()["meta"]["total"] == 1
    assert r.json()["data"][0]["house"]["id"] == house.id


# ── Route CŨ vẫn đúng hành vi sau khi dùng chung content_ops ─────────────────


def _legacy_client(db, *routers) -> TestClient:
    api = FastAPI()
    for r in routers:
        api.include_router(r)

    def override():
        yield db

    api.dependency_overrides[get_db] = override
    return TestClient(api)


def test_legacy_admin_houses_moderate_still_works(db, user):
    from app.routers.admin_houses import router

    admin = user(role="admin")
    host = user()
    house = _house(db, host)
    c = _legacy_client(db, router)
    r = c.post(f"/api/admin/houses/{house.id}/moderate", headers=app_token(admin),
               json={"action": "reject", "reason": "ảnh mờ"})
    assert r.status_code == 200, r.text
    assert r.json()["house"]["status"] == "rejected"
    assert db.query(models.Notification).filter_by(user_id=host.id, type="house_rejected").count() == 1
    assert db.query(models.AuditLog).filter_by(host_id=host.id, action="house_reject").count() == 1
    r = c.post(f"/api/admin/houses/{house.id}/moderate", headers=app_token(admin), json={"action": "reject"})
    assert r.status_code == 422


def test_legacy_verification_complete_still_works(db, user):
    from app.routers.verification import router

    admin = user(role="admin")
    host = user()
    house = _house(db, host)
    req = models.VerificationRequest(house_id=house.id, host_id=host.id, status="requested")
    db.add(req)
    db.commit()
    c = _legacy_client(db, router)
    r = c.post(f"/api/verification/{req.id}/complete", headers=app_token(admin), json={"verified_star": 3})
    assert r.status_code == 200 and r.json()["verified_star"] == 3
    db.expire_all()
    assert db.get(models.House, house.id).quality_verified_star == 3
    assert c.post(f"/api/verification/{req.id}/complete", headers=app_token(admin),
                  json={"verified_star": 3}).status_code == 409
