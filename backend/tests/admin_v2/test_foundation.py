"""Nền Admin V2: đăng nhập, phiên, RBAC từ DB, nhật ký, idempotency, maker-checker."""

from app import models
from app.services.admin_v2 import rbac
from tests.admin_v2.conftest import PASSWORD, app_token, key, w


def test_login_creates_revocable_admin_session(client, db, staff, user):
    u, _ = staff("MODERATOR")
    r = client.post("/api/v2/admin/auth/login", json={"identifier": u.email, "password": PASSWORD})
    assert r.status_code == 200, r.text
    body = r.json()["data"]
    assert "listings.moderate" in body["permissions"] and "payments.read" not in body["permissions"]
    h = {"Authorization": f"Bearer {body['token']}"}
    assert client.get("/api/v2/admin/auth/me", headers=h).status_code == 200
    assert client.post("/api/v2/admin/auth/logout", headers=h).status_code == 200
    r = client.get("/api/v2/admin/auth/me", headers=h)
    assert r.status_code == 401 and r.json()["error"]["code"] == "ADMIN_SESSION_ENDED"
    assert db.query(models.AdminActionLog).filter_by(actor_user_id=u.id, action="admin.login").count() == 1


def test_non_staff_cannot_login_and_attempt_is_logged(client, db, user):
    u = user()
    r = client.post("/api/v2/admin/auth/login", json={"identifier": u.email, "password": PASSWORD})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_NOT_STAFF"
    assert db.query(models.AdminActionLog).filter_by(actor_user_id=u.id, action="admin.login_denied").count() == 1
    bad = client.post("/api/v2/admin/auth/login", json={"identifier": u.email, "password": "sai"})
    assert bad.status_code == 401


def test_admin_token_is_not_an_app_token(client, staff):
    from app.auth import verify_token

    _, h = staff("SUPPORT")
    tok = h["Authorization"].split()[1]
    assert verify_token(tok) is None  # API app thường không nhận token admin


def test_moderator_cannot_reach_finance_and_denial_is_logged(client, db, staff):
    u, h = staff("MODERATOR")
    r = client.get("/api/v2/admin/users", headers=h)
    assert r.status_code == 200
    # Endpoint tài chính (đăng ký ở module finance) — dùng staff list làm đại diện quyền cấm.
    r = client.get("/api/v2/admin/staff", headers=h)
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_PERMISSION_DENIED"
    assert db.query(models.AdminActionLog).filter_by(actor_user_id=u.id, action="permission.denied").count() == 1


def test_permission_is_read_from_db_each_request(client, db, staff):
    boss, hb = staff("SUPER_ADMIN")
    u, h = staff("SUPPORT")
    assert client.get("/api/v2/admin/users", headers=h).status_code == 200
    rbac.revoke_role(db, user_id=u.id, role_code="SUPPORT", revoked_by=boss.id, reason="test")
    db.commit()
    r = client.get("/api/v2/admin/users", headers=h)
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_NOT_STAFF"


def test_locked_account_loses_admin_access_immediately(client, db, staff):
    u, h = staff("SUPER_ADMIN")
    u.is_active = False
    db.commit()
    assert client.get("/api/v2/admin/auth/me", headers=h).status_code == 401


def test_cannot_grant_self_and_super_admin_needs_second_approver(client, db, staff, user):
    a, ha = staff("SUPER_ADMIN")
    b, hb = staff("SUPER_ADMIN")
    target = user(name="Ứng viên")
    r = client.post(f"/api/v2/admin/staff/{a.id}/roles", headers=w(ha), json={"role_code": "FINANCE", "reason": "tự cấp thử"})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_SELF_ROLE_CHANGE"

    r = client.post(f"/api/v2/admin/staff/{target.id}/roles", headers=w(ha), json={"role_code": "SUPER_ADMIN", "reason": "trưởng ca mới"})
    assert r.status_code == 200, r.text
    cr = r.json()["data"]["change_request"]
    assert r.json()["data"]["pending_approval"] is True
    assert "SUPER_ADMIN" not in rbac.active_roles(db, target.id)

    # Người tạo không được tự duyệt.
    r = client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(ha), json={"note": ""})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_MAKER_CHECKER"
    r = client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(hb), json={"note": "ok"})
    assert r.status_code == 200, r.text
    db.expire_all()
    assert "SUPER_ADMIN" in rbac.active_roles(db, target.id)
    assert db.get(models.User, target.id).role == "admin"  # lối tắt Flutter cũ


def test_sensitive_grant_requires_reauth_and_reason(client, staff, user):
    _, h = staff("SUPER_ADMIN", reauth=False)
    t = user()
    r = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=w(h), json={"role_code": "MODERATOR", "reason": "ca đêm"})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_REAUTH_REQUIRED"
    _, h2 = staff("SUPER_ADMIN")
    r = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=w(h2), json={"role_code": "MODERATOR", "reason": ""})
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_REASON_REQUIRED"


def test_cannot_revoke_last_super_admin(client, db, staff, user):
    a, ha = staff("SUPER_ADMIN")
    # Chỉ còn đúng một SUPER_ADMIN khác ngoài a? Tạo b rồi thu b → còn a: được.
    b, _ = staff("SUPER_ADMIN")
    existing = db.query(models.AdminUserRole).filter_by(role_code="SUPER_ADMIN", revoked_at=None).count()
    r = client.post(f"/api/v2/admin/staff/{b.id}/roles/SUPER_ADMIN/revoke", headers=w(ha), json={"reason": "nghỉ việc"})
    assert r.status_code == 200, r.text
    if existing == 2:
        c, hc = staff("SUPER_ADMIN")
        rbac.revoke_role(db, user_id=c.id, role_code="SUPER_ADMIN", revoked_by=None, reason="x")
        db.commit()


def test_idempotent_replay_does_not_duplicate(client, db, staff, user):
    _, h = staff("SUPER_ADMIN")
    t = user()
    hdr = {**h, "Idempotency-Key": key()}
    body = {"role_code": "SUPPORT", "reason": "hỗ trợ ca ngày"}
    first = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=hdr, json=body)
    again = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=hdr, json=body)
    assert first.status_code == again.status_code == 200
    assert again.json()["meta"]["idempotent_replay"] is True
    assert db.query(models.AdminActionLog).filter_by(action="staff.role_grant", entity_id=str(t.id)).count() == 1
    missing = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=h, json=body)
    assert missing.status_code == 428


def test_suspend_revokes_app_tokens_and_requires_if_match(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    t = user()
    app_h = app_token(t)
    row = client.get(f"/api/v2/admin/users/{t.id}", headers=h).json()["data"]
    r = client.post(f"/api/v2/admin/users/{t.id}/suspend", headers=w(h), json={"reason": "gian lận cọc"})
    assert r.status_code == 428
    r = client.post(f"/api/v2/admin/users/{t.id}/suspend", headers=w(h, "sai-phien-ban"), json={"reason": "gian lận cọc"})
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_CONFLICT"
    r = client.post(f"/api/v2/admin/users/{t.id}/suspend", headers=w(h, row["version"]), json={"reason": "gian lận cọc"})
    assert r.status_code == 200, r.text
    db.expire_all()
    from app import auth

    claims = auth.verify_token(app_h["Authorization"].split()[1])
    assert auth._token_da_bi_vo_hieu(db, claims) is True
    log = db.query(models.AdminActionLog).filter_by(action="user.suspend", entity_id=str(t.id)).one()
    assert log.reason == "gian lận cọc" and log.before_json == {"is_active": True}


def test_user_list_is_paginated_and_masked(client, staff, user):
    _, h = staff("SUPPORT")
    for i in range(3):
        user(name=f"Khách {i}", email=f"khach{i}@vidu.vn")
    r = client.get("/api/v2/admin/users?limit=2&q=khach", headers=h)
    body = r.json()
    assert r.status_code == 200 and len(body["data"]) == 2 and body["meta"]["total"] == 3
    assert body["meta"]["next_cursor"] == "2"
    row = body["data"][0]
    assert "email" not in row and row["email_masked"].startswith("kh***@")
    assert "id_number" not in row


def test_reveal_pii_needs_permission_and_reason(client, db, staff, user):
    _, hs = staff("SUPPORT")
    _, hc = staff("COMPLIANCE")
    t = user(id_number="012345678901")
    assert client.post(f"/api/v2/admin/users/{t.id}/reveal-pii", headers=hs, json={"reason": "khách gọi"}).status_code == 403
    assert client.post(f"/api/v2/admin/users/{t.id}/reveal-pii", headers=hc, json={"reason": ""}).status_code == 422
    r = client.post(f"/api/v2/admin/users/{t.id}/reveal-pii", headers=hc, json={"reason": "xác minh khiếu nại #12"})
    assert r.status_code == 200 and r.json()["data"]["id_number"] == "012345678901"
    assert db.query(models.AdminActionLog).filter_by(action="pii.reveal", entity_id=str(t.id)).count() == 1


def test_error_envelope_shape(client, staff):
    _, h = staff("SUPPORT")
    r = client.get("/api/v2/admin/users/999999999", headers=h)
    assert r.status_code == 404
    assert set(r.json()["error"]) >= {"code", "message"}


def test_app_token_of_legacy_admin_still_works(client, db, user):
    u = user(role="admin")
    rbac.grant_role(db, user_id=u.id, role_code="SUPER_ADMIN", granted_by=None, reason="legacy")
    db.commit()
    assert client.get("/api/v2/admin/auth/me", headers=app_token(u)).status_code == 200


def test_dashboard_and_work_items(client, db, staff, user):
    _, h = staff("MODERATOR")
    host = user()
    db.add(models.House(host_id=host.id, title="Căn hộ 2PN", category_id=1, price=1, status="pending_review"))
    db.commit()
    d = client.get("/api/v2/admin/dashboard", headers=h)
    assert d.status_code == 200, d.text
    groups = d.json()["data"]["groups"]
    assert groups["moderation"]["status"] == "ok" and groups["moderation"]["metrics"]["listings_pending"] >= 1
    assert groups["finance"] is None  # moderator không thấy nhóm tài chính
    r = client.get("/api/v2/admin/work-items", headers=h)
    assert r.status_code == 200, r.text
    items = r.json()["data"]
    it = next(i for i in items if i["type"] == "listing_review")
    assert it["ref"].startswith("TIN-") and "deposit_review" not in r.json()["meta"]["counts_by_type"]
    a = client.post(f"/api/v2/admin/work-items/listing_review/{it['source_id']}/assign",
                    headers=w(h, "0"), json={"priority": "high", "note": "ảnh mờ"})
    assert a.status_code == 200, a.text
    assert a.json()["data"]["priority"] == "high" and a.json()["data"]["version"] == "1"
    stale = client.post(f"/api/v2/admin/work-items/listing_review/{it['source_id']}/assign",
                        headers=w(h, "0"), json={"priority": "low"})
    assert stale.status_code == 409


def test_manual_work_item_create_assign_done(client, db, staff):
    a, h = staff("OPS_ADMIN")
    r = client.post("/api/v2/admin/work-items", headers=w(h), json={
        "title": "Gọi lại khách khiếu nại cọc", "priority": "high", "assignee_user_id": a.id,
        "link": "/admin/users/1"})
    assert r.status_code == 200, r.text
    it = r.json()["data"]
    assert it["type"] == "manual" and it["ref"].startswith("CV-") and it["assignee"]["id"] == a.id
    bad = client.post("/api/v2/admin/work-items", headers=w(h), json={"title": "x link", "link": "https://evil.test"})
    assert bad.status_code == 422
    lst = client.get("/api/v2/admin/work-items?type=manual", headers=h).json()
    assert any(x["id"] == it["id"] for x in lst["data"]) and "approvals" in lst["meta"]["tabs"]
    done = client.post(f"/api/v2/admin/work-items/manual/{it['source_id']}/assign", headers=w(h, it["version"]),
                       json={"status": "done"})
    assert done.status_code == 200, done.text
    assert not any(x["id"] == it["id"] for x in client.get("/api/v2/admin/work-items?type=manual", headers=h).json()["data"])
    finished = client.get("/api/v2/admin/work-items?state=done", headers=h).json()["data"]
    assert any(x["id"] == it["id"] and x["done_at"] for x in finished)


def test_suspend_requires_recent_reauth(client, staff, user):
    _, h = staff("COMPLIANCE", reauth=False)
    t = user()
    v = client.get(f"/api/v2/admin/users/{t.id}", headers=h).json()["data"]["version"]
    r = client.post(f"/api/v2/admin/users/{t.id}/suspend", headers=w(h, v), json={"reason": "báo cáo gian lận"})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_REAUTH_REQUIRED"


def test_roles_have_member_counts(client, staff):
    _, h = staff("SUPER_ADMIN")
    roles = client.get("/api/v2/admin/roles", headers=h).json()["data"]["roles"]
    sup = next(x for x in roles if x["code"] == "SUPER_ADMIN")
    assert sup["member_count"] >= 1


def test_change_role_replaces_old_role(client, db, staff, user):
    _, h = staff("SUPER_ADMIN")
    t = user()
    rbac.grant_role(db, user_id=t.id, role_code="SUPPORT", granted_by=None, reason="x")
    db.commit()
    r = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=w(h),
                    json={"role_code": "OPS_ADMIN", "replace_role": "SUPPORT", "reason": "chuyển sang vận hành"})
    assert r.status_code == 200, r.text
    db.expire_all()
    assert rbac.active_roles(db, t.id) == ["OPS_ADMIN"]
    _, h2 = staff("SUPER_ADMIN")
    r = client.post(f"/api/v2/admin/staff/{t.id}/roles", headers=w(h2),
                    json={"role_code": "SUPER_ADMIN", "replace_role": "OPS_ADMIN", "reason": "lên trưởng ca"})
    cr = r.json()["data"]["change_request"]
    detail = client.get(f"/api/v2/admin/change-requests/{cr['id']}", headers=h).json()["data"]
    assert any(p["label"] == "Quyền bị bỏ" for p in detail["preview"]) and detail["can_decide"] is True
    assert client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(h), json={"note": "ok"}).status_code == 200
    db.expire_all()
    assert rbac.active_roles(db, t.id) == ["SUPER_ADMIN"]


def test_work_item_with_uuid_source_can_be_opened_and_assigned(client, db, staff, user):
    """Tranh chấp có khoá UUID: hộp việc phải mở và phân công được (từng 404)."""
    import uuid
    from datetime import datetime

    from app.domain.tenant_authority import TenantAuthorityFlag

    a, h = staff("COMPLIANCE")
    op = user()
    flag = TenantAuthorityFlag(id=str(uuid.uuid4()), tenant_id=1, reported_operator_user_id=op.id,
                               report_reason="Người vận hành không có uỷ quyền", status="pending",
                               created_at=datetime.utcnow())
    db.add(flag)
    db.commit()
    r = client.get(f"/api/v2/admin/work-items/dispute/{flag.id}", headers=h)
    assert r.status_code == 200, r.text
    a2 = client.post(f"/api/v2/admin/work-items/dispute/{flag.id}/assign", headers=w(h, "0"),
                     json={"assignee_user_id": a.id})
    assert a2.status_code == 200, a2.text
    assert a2.json()["data"]["assignee"]["id"] == a.id
