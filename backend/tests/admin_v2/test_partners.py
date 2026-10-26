"""Admin V2 — module Đối tác + cấu hình: hồ sơ Sale, Sale/liên kết, nhà thầu,
lead, yêu cầu dịch vụ, xem liên hệ có lý do, chính sách cọc, tỉnh quy hoạch."""

from __future__ import annotations

from datetime import datetime

from app import models
from app.domain.service_request import Service, ServiceRequest
from app.services import provinces_service
from tests.admin_v2.conftest import key, w

BASE = "/api/v2/admin"


def _application(db, applicant, **kw) -> models.SaleApplication:
    a = models.SaleApplication(
        applicant_user_id=applicant.id, full_name=kw.pop("full_name", "Nguyễn Sale"),
        email=applicant.email, phone=applicant.phone, status=kw.pop("status", "SUBMITTED"),
        evidence_urls=["/uploads/private/cccd.jpg"], service_areas=["Quận 7"], **kw,
    )
    db.add(a)
    db.commit()
    return a


# ── Hồ sơ Sale ───────────────────────────────────────────────────────────────


def test_sale_application_list_masked_and_detail_flags_private_evidence(client, db, staff, user):
    _, h = staff("SUPPORT")
    ap = user(email="ungvien@vidu.vn")
    a = _application(db, ap)
    r = client.get(f"{BASE}/partners/sale-applications?q=SA-{a.id:05d}", headers=h)
    assert r.status_code == 200, r.text
    row = r.json()["data"][0]
    assert row["email_masked"].startswith("un***@") and "email" not in row and row["version"] == "1"
    d = client.get(f"{BASE}/partners/sale-applications/{a.id}", headers=h).json()["data"]
    assert d["evidence"] == [{"path": "/uploads/private/cccd.jpg", "private": True}]
    assert "start_review" in d["allowed_decisions"]
    # SUPPORT chỉ đọc.
    r = client.post(f"{BASE}/partners/sale-applications/{a.id}/decisions", headers=w(h, "1"),
                    json={"decision": "approve"})
    assert r.status_code == 403


def test_sale_application_approve_grants_sale_and_notifies(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    ap = user()
    a = _application(db, ap)
    url = f"{BASE}/partners/sale-applications/{a.id}/decisions"
    r = client.post(url, headers=w(h, "1"), json={"decision": "start_review"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "IN_REVIEW" and r.json()["data"]["version"] == "2"
    stale = client.post(url, headers=w(h, "1"), json={"decision": "approve"})
    assert stale.status_code == 409 and stale.json()["error"]["code"] == "ADMIN_CONFLICT"
    r = client.post(url, headers=w(h, "2"), json={"decision": "approve", "reason": "đủ hồ sơ"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "APPROVED" and r.json()["data"]["approved_sale_profile_id"]
    db.expire_all()
    assert db.get(models.User, ap.id).account_type == "sale"
    assert db.query(models.SaleProfile).filter_by(user_id=ap.id).count() == 1
    assert db.query(models.Notification).filter_by(user_id=ap.id, type="sale_application_approve").count() == 1
    assert db.query(models.ActivityAuditEvent).filter_by(target_id=a.id, action="SALE_APPLICATION_REVIEW").count() == 1
    again = client.post(url, headers=w(h, "3"), json={"decision": "reject", "reason": "đổi ý rồi"})
    assert again.status_code == 409 and again.json()["error"]["code"] == "ADMIN_INVALID_TRANSITION"


def test_sale_application_reject_requires_reason(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    a = _application(db, user())
    url = f"{BASE}/partners/sale-applications/{a.id}/decisions"
    assert client.post(url, headers=w(h, "1"), json={"decision": "reject", "reason": ""}).status_code == 422
    r = client.post(url, headers=w(h, "1"), json={"decision": "reject", "reason": "Thiếu minh chứng hành nghề"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "REJECTED"
    assert r.json()["data"]["rejection_code"] == "OTHER"
    assert r.json()["data"]["review_note"] == "Thiếu minh chứng hành nghề"


# ── Sale + liên kết ──────────────────────────────────────────────────────────


def test_sales_and_links_lists(client, db, staff, user):
    _, h = staff("SUPPORT")
    sale, owner = user(name="Sale A"), user(name="Chủ B")
    db.add(models.SaleProfile(user_id=sale.id, sale_code=f"SL-T{sale.id}", verified=True))
    b = models.Building(host_id=owner.id, name="Toà Sen")
    db.add(b)
    db.commit()
    db.add(models.SaleOwnerLink(sale_id=sale.id, owner_id=owner.id, building_id=b.id, status="active"))
    db.commit()
    r = client.get(f"{BASE}/partners/sales?q=Sale A", headers=h)
    row = next(x for x in r.json()["data"] if x["user"]["id"] == sale.id)
    assert row["active_links"] == 1 and row["verified"] is True
    r = client.get(f"{BASE}/partners/sale-owner-links?sale_id={sale.id}", headers=h)
    assert r.json()["meta"]["total"] == 1 and r.json()["data"][0]["building"]["name"] == "Toà Sen"


# ── Nhà thầu ─────────────────────────────────────────────────────────────────


def _contractor(db, owner, **kw) -> models.Contractor:
    c = models.Contractor(user_id=owner.id, company_name=kw.pop("company_name", "Công ty XD An Cư"), **kw)
    db.add(c)
    db.commit()
    return c


def test_contractor_legal_verify_uses_lookup_year_and_flags_docs(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    owner = user()
    c = _contractor(db, owner, legal_status="pending", tax_code="0312345678", license_path="/uploads/gcn.jpg",
                    lookup_name="CÔNG TY XD AN CƯ", lookup_year=2012, year_established=2010)
    d = client.get(f"{BASE}/partners/contractors/{c.id}", headers=h).json()["data"]
    assert d["legal"]["license_doc"] == {"path": "/uploads/gcn.jpg", "private": True}
    assert d["legal"]["checks"] == {"name_matches": True, "year_matches": False}
    url = f"{BASE}/partners/contractors/{c.id}/legal-decisions"
    r = client.post(url, headers=w(h, d["version"]), json={"decision": "verify"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["legal"]["established_year"] == 2012 and r.json()["data"]["legal_status"] == "approved"
    assert db.query(models.Notification).filter_by(user_id=owner.id, type="legal_verified").count() == 1
    again = client.post(url, headers=w(h, r.json()["data"]["version"]),
                        json={"decision": "reject", "reason": "giấy tờ giả"})
    assert again.status_code == 409


def test_contractor_legal_reject_needs_reason_and_status_suspend(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    owner = user()
    c = _contractor(db, owner, legal_status="pending", status="active", verified=True)
    v = client.get(f"{BASE}/partners/contractors/{c.id}", headers=h).json()["data"]["version"]
    url = f"{BASE}/partners/contractors/{c.id}/legal-decisions"
    assert client.post(url, headers=w(h, v), json={"decision": "reject"}).status_code == 422
    r = client.post(url, headers=w(h, v), json={"decision": "reject", "reason": "MST không khớp tên"})
    assert r.status_code == 200 and r.json()["data"]["legal"]["legal_note"] == "MST không khớp tên"
    v = r.json()["data"]["version"]
    s = f"{BASE}/partners/contractors/{c.id}/status"
    assert client.post(s, headers=w(h, v), json={"status": "suspended"}).status_code == 422
    r = client.post(s, headers=w(h, v), json={"status": "suspended", "reason": "nhiều khiếu nại"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "suspended"
    lst = client.get(f"{BASE}/partners/contractors?status=suspended", headers=h).json()
    assert any(x["id"] == c.id for x in lst["data"])
    r = client.post(s, headers=w(h, r.json()["data"]["version"]), json={"status": "approved"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "active" and r.json()["data"]["verified"] is True


# ── Lead, yêu cầu dịch vụ, xem liên hệ ──────────────────────────────────────


def test_leads_masked_status_and_reveal_with_reason(client, db, staff, user):
    _, hs = staff("SUPPORT")
    _, hc = staff("COMPLIANCE")
    lead = models.ContactLead(name="Khách Lan", phone="0901234567", source="save_home", status="new")
    db.add(lead)
    db.commit()
    lst = client.get(f"{BASE}/partners/leads?status=new&q=Lan", headers=hs).json()
    row = next(x for x in lst["data"] if x["id"] == lead.id)
    assert row["phone_masked"] == "090****567" and "phone" not in row
    url = f"{BASE}/partners/leads/{lead.id}/status"
    assert client.post(url, headers=w(hs, row["version"]), json={"status": "contacted"}).status_code == 403
    assert client.post(url, headers=w(hc, row["version"]), json={"status": "spam"}).status_code == 422
    r = client.post(url, headers=w(hc, row["version"]), json={"status": "contacted", "note": "đã gọi, hẹn mai"})
    assert r.status_code == 200 and r.json()["data"]["status"] == "contacted"
    rv = f"{BASE}/partners/leads/{lead.id}/reveal-contact"
    assert client.post(rv, headers=hs, json={"reason": "gọi lại khách"}).status_code == 403
    assert client.post(rv, headers=hc, json={"reason": ""}).status_code == 422
    r = client.post(rv, headers=hc, json={"reason": "gọi lại khách"})
    assert r.status_code == 200 and r.json()["data"]["phone"] == "0901234567"
    assert db.query(models.AdminActionLog).filter_by(action="pii.reveal_contact", entity_id=str(lead.id)).count() == 1


def test_service_request_update_sets_contacted_at(client, db, staff):
    _, h = staff("COMPLIANCE")
    db.add(Service(slug="sua-dien-t", name="Sửa điện"))
    sr = ServiceRequest(service_slug="sua-dien-t", name="Anh Minh", phone="0912345678", status="new")
    db.add(sr)
    db.commit()
    row = next(x for x in client.get(f"{BASE}/partners/service-requests?status=new", headers=h).json()["data"]
               if x["id"] == sr.id)
    assert row["service_name"] == "Sửa điện" and row["contacted_at"] is None
    url = f"{BASE}/partners/service-requests/{sr.id}/update"
    assert client.post(url, headers=w(h, row["version"]), json={}).status_code == 422
    r = client.post(url, headers=w(h, row["version"]),
                    json={"status": "scheduled", "scheduled_at": "2026-10-20T02:00:00", "admin_note": "thợ Tùng"})
    assert r.status_code == 200, r.text
    d = r.json()["data"]
    assert d["status"] == "scheduled" and d["contacted_at"] and d["admin_note"] == "thợ Tùng"
    stale = client.post(url, headers=w(h, row["version"]), json={"status": "done"})
    assert stale.status_code == 409


def test_construction_lead_update_assigns_contractor(client, db, staff, user):
    _, h = staff("COMPLIANCE")
    c = _contractor(db, user())
    lead = models.ConstructionLead(service_slug="xay-dung", name="Chị Hoa", phone="0987654321", status="new")
    db.add(lead)
    db.commit()
    row = next(x for x in client.get(f"{BASE}/partners/construction-leads", headers=h).json()["data"]
               if x["id"] == lead.id)
    assert row["phone_masked"].endswith("321") and row["quotes_count"] == 0
    r = client.post(f"{BASE}/partners/construction-leads/{lead.id}/update", headers=w(h, row["version"]),
                    json={"contractor_id": c.id})
    assert r.status_code == 200 and r.json()["data"]["status"] == "assigned"
    assert r.json()["data"]["contractor"]["id"] == c.id and r.json()["data"]["assigned_operator"] is not None


# ── Cấu hình ─────────────────────────────────────────────────────────────────


def test_deposit_policy_goes_through_maker_checker(client, db, staff):
    _, hm = staff("MODERATOR")
    assert client.get(f"{BASE}/settings/deposit-policy", headers=hm).status_code == 403
    _, hf = staff("FINANCE")
    _, hf2 = staff("FINANCE")
    v = client.get(f"{BASE}/settings/deposit-policy", headers=hf).json()["data"]["version"]
    body = {"short_stay_primary_deposit_percent": "15", "long_term_platform_deposit_percent": "40",
            "reason": "điều chỉnh mùa cao điểm"}
    _, hf_noreauth = staff("FINANCE", reauth=False)
    r = client.post(f"{BASE}/settings/deposit-policy", headers=w(hf_noreauth), json=body)
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_REAUTH_REQUIRED"
    assert client.post(f"{BASE}/settings/deposit-policy", headers=w(hf), json={**body, "reason": ""}).status_code == 422
    past = {**body, "effective_at": "2020-01-01T00:00:00"}
    r = client.post(f"{BASE}/settings/deposit-policy", headers=w(hf), json=past)
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_ACTIVITY_POLICY_EFFECTIVE_TIME_INVALID"

    # Bản nháp: chưa cần lý do/xác thực lại, chỉ người lập thấy.
    draft = client.post(f"{BASE}/settings/deposit-policy", headers=w(hf_noreauth),
                        json={**body, "reason": "", "submit": False})
    assert draft.status_code == 200, draft.text
    d = draft.json()["data"]["change_request"]
    assert d["status"] == "DRAFT" and d["preview"][1]["after"] == "40%"
    assert client.get(f"{BASE}/change-requests/{d['id']}", headers=hf2).status_code == 404

    hdr = {**hf, "Idempotency-Key": key()}
    r = client.post(f"{BASE}/settings/deposit-policy", headers=hdr, json=body)
    assert r.status_code == 200, r.text
    cr = r.json()["data"]["change_request"]
    assert cr["status"] == "PENDING"
    replay = client.post(f"{BASE}/settings/deposit-policy", headers=hdr, json=body)
    assert replay.json()["meta"]["idempotent_replay"] is True
    # Chưa áp dụng cho tới khi người khác duyệt.
    assert client.get(f"{BASE}/settings/deposit-policy", headers=hf).json()["data"]["version"] == v
    assert client.post(f"{BASE}/change-requests/{cr['id']}/approve", headers=w(hf), json={"note": ""}).status_code == 403
    ok = client.post(f"{BASE}/change-requests/{cr['id']}/approve", headers=w(hf2), json={"note": "đồng ý"})
    assert ok.status_code == 200, ok.text
    state = client.get(f"{BASE}/settings/deposit-policy", headers=hf).json()["data"]
    assert state["version"] == str(int(v) + 1)
    assert state["active"]["short_stay_primary_deposit_percent"] == "15"
    assert state["active"]["long_term_platform_deposit_percent"] == "40"


def test_planning_province_toggle_and_catalog(client, db, staff):
    _, hm = staff("MODERATOR")
    _, ha = staff("SUPER_ADMIN")
    assert client.get(f"{BASE}/settings/planning-provinces", headers=hm).status_code == 403
    slug = provinces_service.list_provinces()[0]["slug"]
    rows = client.get(f"{BASE}/settings/planning-provinces", headers=ha).json()["data"]
    row = next(x for x in rows if x["slug"] == slug)
    url = f"{BASE}/settings/planning-provinces/{slug}"
    target = not row["hidden"]
    assert client.post(url, headers=w(ha, row["version"]), json={"hidden": target}).status_code == 422
    r = client.post(url, headers=w(ha, row["version"]), json={"hidden": target, "reason": "dữ liệu lỗi thời"})
    assert r.status_code == 200 and r.json()["data"]["hidden"] is target
    assert client.post(url, headers=w(ha, row["version"]),
                       json={"hidden": target, "reason": "dữ liệu lỗi thời"}).status_code == 409
    assert client.post(f"{BASE}/settings/planning-provinces/khong-co", headers=w(ha, "x"),
                       json={"hidden": True, "reason": "thử tỉnh lạ"}).status_code == 404
    cat = client.get(f"{BASE}/settings/catalog", headers=hm)
    assert cat.status_code == 200 and set(cat.json()["data"]) == {"categories", "amenities", "services"}
    _, hf = staff("FINANCE")
    assert client.get(f"{BASE}/settings/catalog", headers=hf).status_code == 403


def test_service_request_scheduled_at_is_naive_utc(db):
    """update_service_request bỏ tzinfo như route cũ (cột DateTime không múi)."""
    from datetime import timezone

    from app.services.admin_v2 import partners_ops

    sr = ServiceRequest(service_slug="x", name="a", phone="0900000000", status="new")
    partners_ops.update_service_request(
        sr, status="contacted", scheduled_at=datetime(2026, 10, 20, 2, tzinfo=timezone.utc), admin_note=None)
    assert sr.scheduled_at.tzinfo is None and sr.contacted_at is not None
