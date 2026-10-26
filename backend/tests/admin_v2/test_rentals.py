"""Admin V2 — Giao dịch thuê: hành trình, timeline, lệnh ngoại lệ, booking, hợp đồng."""

from __future__ import annotations

from datetime import datetime, timedelta

from app import models
from tests.admin_v2.conftest import w

T0 = datetime(2026, 9, 20, 8, 0, 0)


def make_journey(db, user, *, status="DEPOSITS_PENDING", proofs=True, updated_at=None):
    """Hồ sơ đủ ba bên + phòng + lịch xem + hai khoản cọc (cọc nền tảng đã nộp)."""
    customer, sale, owner = user(name="Khách Thuê"), user(name="Sale Một"), user(name="Chủ Nhà")
    b = models.Building(host_id=owner.id, name="Toà Sen", sale_id=sale.id)
    db.add(b)
    db.flush()
    room = models.Room(building_id=b.id, code="P101", base_price=8_000_000, status="vacant",
                       owner_id=owner.id, managed_by_sale_id=sale.id)
    db.add(room)
    db.flush()
    appt = models.ViewingAppointment(room_id=room.id, guest_id=customer.id, loai="xem", booking_date="2026-09-20",
                                     booking_time="10:00-11:00", status="completed", created_at=T0,
                                     ten_khach="Khách Thuê", sdt_khach="0901234567")
    db.add(appt)
    db.flush()
    j = models.RentalJourney(appointment_id=appt.id, room_id=room.id, customer_id=customer.id, sale_id=sale.id,
                             owner_id=owner.id, status=status, total_deposit=10_000_000,
                             contract_urls=["/uploads/hop-dong-1.pdf"], contract_submitted_by=sale.id,
                             contract_submitted_at=T0 + timedelta(hours=2), created_at=T0 + timedelta(hours=1),
                             updated_at=updated_at or datetime.utcnow())
    db.add(j)
    db.flush()
    app_p = models.RentalJourneyPayment(
        journey_id=j.id, kind="APP_DEPOSIT", amount=5_000_000,
        status="SUBMITTED" if proofs else "PENDING",
        proof_urls=["/uploads/coc-app.jpg"] if proofs else [],
        submitted_by=customer.id if proofs else None,
        submitted_at=T0 + timedelta(hours=3) if proofs else None)
    own_p = models.RentalJourneyPayment(
        journey_id=j.id, kind="OWNER_DEPOSIT", amount=5_000_000,
        status="SUBMITTED" if proofs else "PENDING",
        proof_urls=["/uploads/coc-chu.jpg"] if proofs else [],
        submitted_by=customer.id if proofs else None,
        submitted_at=T0 + timedelta(hours=4) if proofs else None)
    db.add_all([app_p, own_p])
    db.add_all([
        models.RentalJourneyEvent(journey_id=j.id, actor_id=customer.id, actor_role="customer",
                                  event_type="VIEWING_RESULT_RECORDED", to_status="CUSTOMER_INTERESTED",
                                  created_at=T0 + timedelta(hours=1)),
        models.RentalJourneyEvent(journey_id=j.id, actor_id=sale.id, actor_role="sale",
                                  event_type="CONTRACT_SUBMITTED", from_status="CUSTOMER_INTERESTED",
                                  to_status="CONTRACT_READY", created_at=T0 + timedelta(hours=2)),
        # Nộp cọc chủ nhà có sự kiện; cọc nền tảng KHÔNG có (dữ liệu cũ) → timeline bù từ dòng cọc.
        models.RentalJourneyEvent(journey_id=j.id, actor_id=customer.id, actor_role="customer",
                                  event_type="PAYMENT_PROOF_SUBMITTED", from_status="DEPOSITS_PENDING",
                                  to_status=status, payload={"kind": "OWNER_DEPOSIT"},
                                  created_at=T0 + timedelta(hours=4)),
    ])
    db.commit()
    return {"journey": j, "customer": customer, "sale": sale, "owner": owner, "room": room, "building": b,
            "appointment": appt, "app": app_p, "owner_deposit": own_p}


def test_journey_list_detail_and_document_redaction(client, db, staff, user):
    ctx = make_journey(db, user, updated_at=datetime.utcnow() - timedelta(hours=100))
    j = ctx["journey"]
    _, ops = staff("OPS_ADMIN")
    r = client.get("/api/v2/admin/rentals/journeys?status=stalled", headers=ops)
    assert r.status_code == 200, r.text
    row = next(x for x in r.json()["data"] if x["id"] == j.id)
    assert row["ref"] == f"HT-{j.id:05d}" and row["stalled"] is True
    assert row["customer"]["phone_masked"] != ctx["customer"].phone and "phone" not in row["customer"]
    assert row["deposits"]["APP_DEPOSIT"]["has_proof"] is True
    assert client.get(f"/api/v2/admin/rentals/journeys?q=HT-{j.id:05d}", headers=ops).json()["meta"]["total"] == 1

    d = client.get(f"/api/v2/admin/rentals/journeys/{j.id}", headers=ops).json()["data"]
    assert d["parties"]["owner"]["id"] == ctx["owner"].id and d["appointment"]["id"] == ctx["appointment"].id
    assert d["contract_documents"]["files"] == [{"path": "/uploads/hop-dong-1.pdf", "private": True}]
    dep = {x["kind"]: x for x in d["deposits"]}
    assert dep["APP_DEPOSIT"]["proofs"][0] == {"path": "/uploads/coc-app.jpg", "private": True}
    checklist = {x["code"]: x["done"] for x in d["missing_documents"]}
    assert checklist["contract_documents"] and checklist["owner_deposit_proof"]
    assert checklist["owner_deposit_acknowledged"] is False and d["available_admin_actions"] == ["cancel"]

    # SUPPORT xem được hồ sơ nhưng KHÔNG có rental_documents.read → đường dẫn bị che.
    _, sup = staff("SUPPORT")
    d2 = client.get(f"/api/v2/admin/rentals/journeys/{j.id}", headers=sup).json()["data"]
    assert d2["documents_redacted"] is True and d2["contract_documents"]["files"][0]["path"] is None
    # Danh sách không bao giờ có đường dẫn chứng từ.
    assert "/uploads/" not in str(r.json()["data"])


def test_timeline_is_chronological_and_tags_actor_roles(client, db, staff, user):
    ctx = make_journey(db, user)
    j = ctx["journey"]
    _, ops = staff("OPS_ADMIN")
    detail = client.get(f"/api/v2/admin/rentals/journeys/{j.id}", headers=ops).json()["data"]
    assert client.post(f"/api/v2/admin/rentals/journeys/{j.id}/cancel", headers=w(ops, detail["version"]),
                       json={"reason": "khách yêu cầu qua tổng đài"}).status_code == 200
    r = client.get(f"/api/v2/admin/rentals/journeys/{j.id}/timeline", headers=ops)
    assert r.status_code == 200, r.text
    items = r.json()["data"]
    stamps = [i["at"] for i in items]
    assert stamps == sorted(stamps)
    types = [i["type"] for i in items]
    assert types[:5] == ["VIEWING_BOOKED", "VIEWING_RESULT_RECORDED", "CONTRACT_SUBMITTED", "DEPOSIT_SUBMITTED",
                         "PAYMENT_PROOF_SUBMITTED"]
    assert types.count("DEPOSIT_SUBMITTED") == 1  # cọc chủ nhà đã có sự kiện → không nhân đôi
    roles = {i["type"]: i["actor_role"] for i in items}
    assert roles["CONTRACT_SUBMITTED"] == "sale" and roles["VIEWING_BOOKED"] == "customer"
    assert roles["JOURNEY_CANCELLED"] == "admin" and roles["rental_journey.cancel"] == "admin"
    assert {i["source"] for i in items} >= {"viewing", "journey_event", "deposit", "admin"}


def test_cancel_journey_needs_if_match_reason_and_goes_through_domain(client, db, staff, user):
    ctx = make_journey(db, user)
    j = ctx["journey"]
    _, ops = staff("OPS_ADMIN")
    version = client.get(f"/api/v2/admin/rentals/journeys/{j.id}", headers=ops).json()["data"]["version"]
    url = f"/api/v2/admin/rentals/journeys/{j.id}/cancel"
    body = {"reason": "nghi gian lận cọc", "public_reason": ""}
    assert client.post(url, headers=w(ops), json=body).status_code == 428
    r = client.post(url, headers=w(ops, "phien-ban-cu"), json=body)
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_CONFLICT"
    assert client.post(url, headers=w(ops, version), json={"reason": ""}).status_code == 422
    hdr = w(ops, version)
    r = client.post(url, headers=hdr, json=body)
    assert r.status_code == 200, r.text
    data = r.json()["data"]
    assert data["status"] == "CANCELLED" and data["available_admin_actions"] == []
    again = client.post(url, headers=hdr, json=body)
    assert again.status_code == 200 and again.json()["meta"]["idempotent_replay"] is True
    db.expire_all()
    jj = db.get(models.RentalJourney, j.id)
    # Lý do NỘI BỘ không lộ ra app: hồ sơ mang câu mặc định.
    assert jj.status == "CANCELLED" and "gian lận" not in (jj.cancel_reason or "")
    ev = db.query(models.RentalJourneyEvent).filter_by(journey_id=j.id, event_type="JOURNEY_CANCELLED").one()
    assert ev.actor_role == "admin"
    log = db.query(models.AdminActionLog).filter_by(action="rental_journey.cancel", entity_id=str(j.id)).one()
    assert log.reason == "nghi gian lận cọc" and log.before_json == {"status": "DEPOSITS_PENDING"}
    # Version cũ sau khi huỷ → 409 (If-Match), không huỷ lần hai.
    assert client.post(url, headers=w(ops, version), json=body).status_code == 409


def test_disputed_journey_cannot_be_cancelled_and_report_decision(client, db, staff, user):
    ctx = make_journey(db, user, status="DISPUTED")
    j = ctx["journey"]
    rep = models.RentalJourneyReport(journey_id=j.id, reporter_id=ctx["customer"].id,
                                     reported_user_id=ctx["sale"].id, reason_code="SCAM", detail="đòi thêm tiền",
                                     evidence_urls=["/uploads/bang-chung.png"], status="PENDING")
    db.add(rep)
    db.commit()
    _, ops = staff("OPS_ADMIN")
    d = client.get(f"/api/v2/admin/rentals/journeys/{j.id}", headers=ops).json()["data"]
    assert d["has_dispute"] is True and d["available_admin_actions"] == []
    r = client.post(f"/api/v2/admin/rentals/journeys/{j.id}/cancel", headers=w(ops, d["version"]),
                    json={"reason": "thử huỷ khi tranh chấp"})
    assert r.status_code == 409 and r.json()["error"]["code"] == "ADMIN_TRANSITION_NOT_ALLOWED"

    report = d["reports"][0]
    url = f"/api/v2/admin/rentals/journey-reports/{report['id']}/decisions"
    assert client.post(url, headers=w(ops, report["version"]), json={"decision": "valid", "reason": ""}).status_code == 422
    r = client.post(url, headers=w(ops, report["version"]), json={"decision": "valid", "reason": "đối chiếu tin nhắn"})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "VALID" and r.json()["data"]["journey"]["status"] == "DISPUTED"
    fresh = r.json()["data"]["version"]
    r = client.post(url, headers=w(ops, fresh), json={"decision": "invalid", "reason": "kết luận lại lần hai"})
    assert r.status_code == 409
    # Sự kiện hồ sơ (hiện cho ba bên) không chứa lý do nội bộ.
    ev = db.query(models.RentalJourneyEvent).filter_by(journey_id=j.id, event_type="REPORT_DECIDED").one()
    assert "đối chiếu" not in str(ev.payload)


def _reservation(db, user, status="pending"):
    host, guest = user(name="Chủ Homestay"), user(name="Khách Đêm")
    b = models.Building(host_id=host.id, name="Homestay Biển")
    db.add(b)
    db.flush()
    room = models.Room(building_id=b.id, code="H1", base_price=500_000, status="vacant", owner_id=host.id)
    db.add(room)
    db.flush()
    res = models.Reservation(host_id=host.id, room_id=room.id, guest_user_id=guest.id, guest_name="Khách Đêm",
                             guest_phone="0907654321", check_in_date="2026-12-01", check_out_date="2026-12-03",
                             nights=2, total_amount=1_000_000.4, deposit_paid=100_000, status=status,
                             source="direct", source_id=1, booking_code="BKTEST01")
    db.add(res)
    db.flush()
    db.add(models.RoomChiemDung(room_id=room.id, tu_ngay=datetime(2026, 12, 2).date(),
                                den_ngay=datetime(2026, 12, 5).date(), kenh="khoa", nguon="thu_cong"))
    db.add(models.ReservationPhuThu(reservation_id=res.id, ten="Nước suối", don_gia=10_000, so_luong=2,
                                    thanh_tien=20_000))
    db.commit()
    return res, room


def test_reservation_list_detail_and_commands(client, db, staff, user):
    res, room = _reservation(db, user)
    _, ops = staff("OPS_ADMIN")
    r = client.get("/api/v2/admin/rentals/reservations?q=BKTEST01", headers=ops)
    assert r.status_code == 200 and r.json()["meta"]["total"] == 1
    row = r.json()["data"][0]
    assert row["guest"]["phone_masked"] == "090****321" and row["total_amount"] == 1_000_000
    d = client.get(f"/api/v2/admin/rentals/reservations/{res.id}", headers=ops).json()["data"]
    assert d["money"]["phu_thu"] == 20_000 and d["conflicts"][0]["type"] == "occupancy"
    assert set(d["available_admin_actions"]) == {"approve", "reject", "cancel"}
    url = f"/api/v2/admin/rentals/reservations/{res.id}/reject"
    r = client.post(url, headers=w(ops, d["version"]), json={"reason": "phòng hỏng điện", "public_reason": ""})
    assert r.status_code == 200, r.text
    assert r.json()["data"]["status"] == "rejected"
    assert any(e["source"] == "admin" for e in r.json()["data"]["timeline"]) is False  # log ghi sau fn
    t = client.get(f"/api/v2/admin/rentals/reservations/{res.id}", headers=ops).json()["data"]["timeline"]
    assert [e["type"] for e in t][-1] == "reservation.reject"
    # Đơn đã từ chối không huỷ được nữa — lỗi miền thành 409.
    cur = client.get(f"/api/v2/admin/rentals/reservations/{res.id}", headers=ops).json()["data"]["version"]
    r = client.post(f"/api/v2/admin/rentals/reservations/{res.id}/cancel", headers=w(ops, cur),
                    json={"reason": "thử huỷ đơn đã từ chối"})
    assert r.status_code == 409

    occ = client.get(f"/api/v2/admin/rentals/occupancy?room_id={room.id}&from=2026-11-25&to=2026-12-25", headers=ops)
    assert occ.status_code == 200 and len(occ.json()["data"]["blocks"]) == 1


def test_viewings_sale_requests_contracts(client, db, staff, user):
    ctx = make_journey(db, user)
    owner = ctx["owner"]
    c = models.Contract(host_id=owner.id, room_id=ctx["room"].id, start_date="2026-10-01",
                        end_date=(datetime.utcnow() + timedelta(days=10)).date().isoformat(), monthly_rent=8e6,
                        deposit=1.6e7, status="active", source_id=1, handover_photos=["/uploads/ban-giao.jpg"])
    db.add(c)
    db.flush()
    t = models.Tenant(host_id=owner.id, full_name="Khách Thuê", phone="0901234567", cccd_duoi="789")
    db.add(t)
    db.flush()
    db.add(models.ContractTenant(contract_id=c.id, tenant_id=t.id, is_primary=True))
    db.commit()
    _, ops = staff("OPS_ADMIN")
    v = client.get(f"/api/v2/admin/rentals/viewings?q=LX-{ctx['appointment'].id}", headers=ops).json()
    assert v["meta"]["total"] == 1 and v["data"][0]["journey_id"] == ctx["journey"].id
    assert v["data"][0]["attendee"]["phone_masked"] == "090****567" and v["data"][0]["host"]["id"] == owner.id
    cl = client.get("/api/v2/admin/rentals/contracts?expiring_within_days=30", headers=ops).json()
    assert [x["id"] for x in cl["data"]] == [c.id] and cl["data"][0]["monthly_rent"] == 8_000_000
    cd = client.get(f"/api/v2/admin/rentals/contracts/{c.id}", headers=ops).json()["data"]
    assert cd["tenants"][0]["cccd_last3_masked"].endswith("789") and cd["handover_photos"][0]["private"] is True


def test_moderator_and_support_limits(client, db, staff, user):
    ctx = make_journey(db, user)
    _, mod = staff("MODERATOR")
    assert client.get("/api/v2/admin/rentals/journeys", headers=mod).status_code == 403
    _, sup = staff("SUPPORT")
    v = client.get(f"/api/v2/admin/rentals/journeys/{ctx['journey'].id}", headers=sup).json()["data"]["version"]
    r = client.post(f"/api/v2/admin/rentals/journeys/{ctx['journey'].id}/cancel", headers=w(sup, v),
                    json={"reason": "support thử huỷ"})
    assert r.status_code == 403
    # Không có quyền thì 403 trước cả khi thiếu Idempotency-Key (không lộ gì).
    r = client.post(f"/api/v2/admin/rentals/journeys/{ctx['journey'].id}/cancel", headers=mod, json={})
    assert r.status_code == 403
