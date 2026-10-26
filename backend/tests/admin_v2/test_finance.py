"""Admin V2 — Tài chính: phân quyền, ghi nhận thanh toán/hoàn tiền (idempotent,
maker-checker), xác minh cọc record-only, đối soát, chính sách cọc."""

from __future__ import annotations

from app import models
from app.services.admin_v2.permissions import REFUND_DUAL_APPROVAL_THRESHOLD
from tests.admin_v2.conftest import w
from tests.admin_v2.test_rentals import make_journey

FINANCE_GETS = [
    "/api/v2/admin/finance/overview",
    "/api/v2/admin/finance/deposits",
    "/api/v2/admin/finance/deposits/1",
    "/api/v2/admin/finance/payments",
    "/api/v2/admin/finance/payments/1",
    "/api/v2/admin/finance/reconciliation",
    "/api/v2/admin/finance/invoices",
    "/api/v2/admin/finance/refunds",
    "/api/v2/admin/finance/commissions",
    "/api/v2/admin/finance/settlements",
    "/api/v2/admin/settings/deposit-policy",
]
FINANCE_POSTS = [
    "/api/v2/admin/finance/deposits/1/verify",
    "/api/v2/admin/finance/payments",
    "/api/v2/admin/finance/payments/1/refund-records",
    "/api/v2/admin/finance/payments/1/reconcile",
    "/api/v2/admin/settings/deposit-policy",
]


def _invoice(db, user):
    host = user(name="Chủ Hoá Đơn")
    b = models.Building(host_id=host.id, name="Toà HĐ")
    db.add(b)
    db.flush()
    room = models.Room(building_id=b.id, code="A1", base_price=5e6, owner_id=host.id)
    db.add(room)
    db.flush()
    c = models.Contract(host_id=host.id, room_id=room.id, start_date="2026-01-01", end_date="2027-01-01",
                        monthly_rent=5e6, deposit=1e7, status="active", source_id=1)
    db.add(c)
    db.flush()
    inv = models.Invoice(host_id=host.id, contract_id=c.id, invoice_number=f"HD-{c.id}-09", period_start="2026-09-01",
                         period_end="2026-09-30", issued_date="2026-09-01", due_date="2026-09-05", status="sent",
                         total_amount=12_000_000, paid_amount=0)
    db.add(inv)
    db.commit()
    return inv, host


def _payment_body(inv, payer, amount=12_000_000, ref="CK-0001"):
    return {
        "source_type": "INVOICE", "source_id": inv.id, "payer_user_id": payer.id, "amount": amount,
        "method": "BANK_TRANSFER", "external_reference": ref, "evidence_urls": ["/uploads/ck.jpg"],
        "paid_at": "2026-09-04T09:00:00",
        "allocations": [{"allocation_type": "OWNER_NET", "beneficiary_user_id": payer.id, "amount": amount - 1_000_000},
                        {"allocation_type": "PLATFORM_FEE", "amount": 1_000_000, "rule_version": "v1"}],
        "note": "đối chiếu sao kê VCB",
    }


def test_moderator_cannot_access_any_finance_endpoint_even_knowing_url(client, db, staff):
    u, mod = staff("MODERATOR")
    for url in FINANCE_GETS:
        r = client.get(url, headers=mod)
        assert r.status_code == 403, (url, r.status_code)
        assert r.json()["error"]["code"] == "ADMIN_PERMISSION_DENIED"
    for url in FINANCE_POSTS:
        for hdr in (mod, w(mod, "x")):  # có hay không Idempotency-Key đều 403
            r = client.post(url, headers=hdr, json={})
            assert r.status_code == 403, (url, r.status_code, r.text)
    n = db.query(models.AdminActionLog).filter_by(actor_user_id=u.id, action="permission.denied").count()
    assert n == len(FINANCE_GETS) + 2 * len(FINANCE_POSTS)


def test_finance_cannot_moderate_content(client, staff):
    _, fin = staff("FINANCE")
    assert client.get("/api/v2/admin/listings", headers=fin).status_code == 403
    assert client.get("/api/v2/admin/content-reports", headers=fin).status_code == 403
    r = client.post("/api/v2/admin/listings/1/moderation-decisions", headers=w(fin, "0"),
                    json={"decision": "approve", "reason": "tài chính thử duyệt"})
    assert r.status_code == 403
    assert client.get("/api/v2/admin/finance/overview", headers=fin).status_code == 200


def test_record_payment_validates_and_replay_does_not_duplicate(client, db, staff, user):
    inv, host = _invoice(db, user)
    _, fin = staff("FINANCE")
    bad = _payment_body(inv, host)
    bad["allocations"][0]["amount"] -= 1
    r = client.post("/api/v2/admin/finance/payments", headers=w(fin), json=bad)
    assert r.status_code == 422 and r.json()["error"]["code"] == "ADMIN_ALLOCATION_UNBALANCED"
    ghost = {**_payment_body(inv, host), "source_id": 99999999}
    assert client.post("/api/v2/admin/finance/payments", headers=w(fin), json=ghost).json()["error"]["code"] \
        == "ADMIN_SOURCE_NOT_FOUND"
    evil = {**_payment_body(inv, host), "evidence_urls": ["javascript:alert(1)"]}
    assert client.post("/api/v2/admin/finance/payments", headers=w(fin), json=evil).status_code == 422

    hdr = w(fin)
    first = client.post("/api/v2/admin/finance/payments", headers=hdr, json=_payment_body(inv, host))
    again = client.post("/api/v2/admin/finance/payments", headers=hdr, json=_payment_body(inv, host))
    assert first.status_code == 200, first.text
    assert again.json()["meta"]["idempotent_replay"] is True and again.json()["data"]["id"] == first.json()["data"]["id"]
    assert db.query(models.PlatformPayment).filter_by(source_type="INVOICE", source_id=inv.id).count() == 1
    data = first.json()["data"]
    assert data["amount"] == 12_000_000 and data["mismatch"] is False and data["transfer_execution"] == "DISABLED"
    assert data["evidence"] == [{"path": "/uploads/ck.jpg", "private": True}]
    # Cùng mã chứng từ với KHOÁ MỚI = trùng thật → 409 chứ không tạo khoản thứ hai.
    dup = client.post("/api/v2/admin/finance/payments", headers=w(fin), json=_payment_body(inv, host))
    assert dup.status_code == 409 and dup.json()["error"]["code"] == "ADMIN_DUPLICATE_REFERENCE"
    lst = client.get("/api/v2/admin/finance/payments?q=CK-0001", headers=fin).json()
    assert lst["meta"]["total"] == 1 and "evidence" not in lst["data"][0]


def test_refund_below_threshold_is_recorded_once(client, db, staff, user):
    inv, host = _invoice(db, user)
    _, fin = staff("FINANCE")
    pay = client.post("/api/v2/admin/finance/payments", headers=w(fin), json=_payment_body(inv, host)).json()["data"]
    url = f"/api/v2/admin/finance/payments/{pay['id']}/refund-records"
    body = {"amount": 500_000, "reason_code": "OVERPAYMENT", "note": "thu thừa", "reason": "khách chuyển dư"}
    assert client.post(url, headers=w(fin), json=body).status_code == 428  # thiếu If-Match
    assert client.post(url, headers=w(fin, pay["version"]), json={**body, "reason": ""}).status_code == 422
    hdr = w(fin, pay["version"])
    r1 = client.post(url, headers=hdr, json=body)
    r2 = client.post(url, headers=hdr, json=body)
    assert r1.status_code == 200, r1.text
    assert r1.json()["data"]["pending_approval"] is False and r1.json()["data"]["payment"]["refunded_amount"] == 500_000
    assert r2.json()["meta"]["idempotent_replay"] is True
    assert db.query(models.MoneyRefund).filter_by(payment_id=pay["id"]).count() == 1
    # Phiên bản cũ sau khi ghi hoàn → 409.
    assert client.post(url, headers=w(fin, pay["version"]), json=body).status_code == 409
    fresh = r1.json()["data"]["payment"]["version"]
    over = client.post(url, headers=w(fin, fresh), json={**body, "amount": 11_600_000})
    assert over.status_code == 422 and over.json()["error"]["code"] == "ADMIN_REFUND_EXCEEDS_PAYMENT"


def test_refund_at_threshold_needs_second_approver(client, db, staff, user):
    inv, host = _invoice(db, user)
    a, fa = staff("FINANCE")
    b, fb = staff("FINANCE")
    pay = client.post("/api/v2/admin/finance/payments", headers=w(fa), json=_payment_body(inv, host)).json()["data"]
    url = f"/api/v2/admin/finance/payments/{pay['id']}/refund-records"
    body = {"amount": REFUND_DUAL_APPROVAL_THRESHOLD, "reason_code": "CUSTOMER_CANCELLED", "note": "",
            "reason": "khách huỷ trước hạn"}
    hdr = w(fa, pay["version"])
    r = client.post(url, headers=hdr, json=body)
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    assert data["pending_approval"] is True and data["refund"] is None
    cr = data["change_request"]
    assert cr["kind"] == "refund_record" and cr["status"] == "PENDING"
    assert db.query(models.MoneyRefund).filter_by(payment_id=pay["id"]).count() == 0
    # Gửi lại cùng khoá không đẻ yêu cầu thứ hai.
    assert client.post(url, headers=hdr, json=body).json()["meta"]["idempotent_replay"] is True
    assert db.query(models.AdminChangeRequest).filter_by(kind="refund_record").count() == 1
    # Yêu cầu đang chờ GIỮ chỗ: thêm một yêu cầu vượt phần còn lại bị chặn.
    cur = client.get(f"/api/v2/admin/finance/payments/{pay['id']}", headers=fa).json()["data"]
    assert cur["refundable_amount"] == 12_000_000 - REFUND_DUAL_APPROVAL_THRESHOLD
    over = client.post(url, headers=w(fa, cur["version"]), json={**body, "amount": 8_000_000})
    assert over.status_code == 422

    r = client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(fa), json={"note": ""})
    assert r.status_code == 403 and r.json()["error"]["code"] == "ADMIN_MAKER_CHECKER"
    _, mod = staff("MODERATOR")
    assert client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(mod),
                       json={"note": ""}).status_code == 403
    r = client.post(f"/api/v2/admin/change-requests/{cr['id']}/approve", headers=w(fb), json={"note": "đã kiểm"})
    assert r.status_code == 200, r.text
    db.expire_all()
    refunds = db.query(models.MoneyRefund).filter_by(payment_id=pay["id"]).all()
    assert len(refunds) == 1 and int(refunds[0].amount) == REFUND_DUAL_APPROVAL_THRESHOLD
    assert refunds[0].recorded_by_user_id == a.id
    assert r.json()["data"]["result"]["approved_by"] == b.id


def test_deposit_verify_is_record_only_and_owner_ack_goes_through_domain(client, db, staff, user):
    ctx = make_journey(db, user)
    j, app_p, own_p = ctx["journey"], ctx["app"], ctx["owner_deposit"]
    _, fin = staff("FINANCE")
    lst = client.get("/api/v2/admin/finance/deposits?status=SUBMITTED&verification=unverified", headers=fin).json()
    row = next(x for x in lst["data"] if x["id"] == app_p.id)
    assert row["proof_count"] == 1 and "proofs" not in row
    url = f"/api/v2/admin/finance/deposits/{app_p.id}/verify"
    assert client.post(url, headers=w(fin, row["version"]), json={"decision": "rejected", "reason": ""}).status_code == 422
    r = client.post(url, headers=w(fin, row["version"]), json={"decision": "verified", "reason": ""})
    assert r.status_code == 200, r.text
    d = r.json()["data"]
    assert d["admin_verification"]["decision"] == "verified" and d["verification_state"] == "verified"
    db.expire_all()
    # Record-only: không đổi trạng thái khoản cọc hay hồ sơ.
    assert db.get(models.RentalJourneyPayment, app_p.id).status == "SUBMITTED"
    assert db.get(models.RentalJourney, j.id).status == "DEPOSITS_PENDING"
    # Rời hộp việc "Đối soát cọc".
    items = client.get("/api/v2/admin/work-items?type=deposit_review", headers=fin).json()["data"]
    assert all(i["source_id"] != str(app_p.id) for i in items)
    # Phiên bản trả về dùng được ngay cho lệnh kế tiếp (không 409 giả).
    r = client.post(url, headers=w(fin, d["version"]), json={"decision": "rejected", "reason": "ảnh mờ không đọc được"})
    assert r.status_code == 200 and r.json()["data"]["verification_state"] == "rejected"

    own = client.get(f"/api/v2/admin/finance/deposits/{own_p.id}", headers=fin).json()["data"]
    assert own["can_acknowledge_owner_deposit"] is True and own["proofs"][0]["private"] is True
    bad = client.post(f"/api/v2/admin/finance/deposits/{app_p.id}/verify",
                      headers=w(fin, r.json()["data"]["version"]),
                      json={"decision": "verified", "reason": "x", "acknowledge_owner_deposit": True})
    assert bad.status_code == 422
    r = client.post(f"/api/v2/admin/finance/deposits/{own_p.id}/verify", headers=w(fin, own["version"]),
                    json={"decision": "verified", "reason": "chủ nhà xác nhận qua điện thoại",
                          "acknowledge_owner_deposit": True})
    assert r.status_code == 200, r.text
    db.expire_all()
    p = db.get(models.RentalJourneyPayment, own_p.id)
    assert p.status == "ACKNOWLEDGED" and p.acknowledged_at is not None
    ev = db.query(models.RentalJourneyEvent).filter_by(journey_id=j.id, event_type="OWNER_DEPOSIT_ACKNOWLEDGED").one()
    assert ev.actor_role == "admin"


def test_reconcile_overview_and_read_lists(client, db, staff, user):
    inv, host = _invoice(db, user)
    _, fin = staff("FINANCE")
    pay = client.post("/api/v2/admin/finance/payments", headers=w(fin), json=_payment_body(inv, host)).json()["data"]
    url = f"/api/v2/admin/finance/payments/{pay['id']}/reconcile"
    r = client.post(url, headers=w(fin, pay["version"]), json={"note": "khớp sao kê"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["reconciled"]["note"] == "khớp sao kê"
    assert client.post(url, headers=w(fin, r.json()["data"]["version"]), json={}).status_code == 409
    assert client.get("/api/v2/admin/finance/payments?reconciled=true", headers=fin).json()["meta"]["total"] == 1

    # Khoản lệch phân bổ (dữ liệu cũ ghi tay) hiện ở bảng đối soát và không đánh dấu được.
    odd = models.PlatformPayment(source_type="INVOICE", source_id=inv.id, amount=300_000, external_reference="TAY-1",
                                 recorded_by_user_id=host.id, paid_at=inv.created_at)
    db.add(odd)
    db.commit()
    rec = client.get("/api/v2/admin/finance/reconciliation", headers=fin).json()
    assert [x["id"] for x in rec["data"]] == [odd.id] and rec["meta"]["summary"]["balanced"] is False
    ov = client.get("/api/v2/admin/finance/overview", headers=fin).json()["data"]
    assert ov["transfer_execution"] == "DISABLED" and ov["counts"]["allocation_mismatches"] == 1
    assert ov["counts"]["invoices_overdue"] >= 1 and ov["totals"]["payment_total"] == 12_300_000
    inv_rows = client.get("/api/v2/admin/finance/invoices?overdue=true", headers=fin).json()["data"]
    assert any(x["id"] == inv.id and x["outstanding"] == 12_000_000 for x in inv_rows)
    for path in ("refunds", "commissions", "settlements"):
        assert client.get(f"/api/v2/admin/finance/{path}", headers=fin).status_code == 200
