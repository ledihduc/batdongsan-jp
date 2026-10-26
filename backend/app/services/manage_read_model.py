"""Read-only Activity hub projection; legacy commands remain untouched."""

from __future__ import annotations

from datetime import datetime

from fastapi import HTTPException
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.services import rental_journey_policy
from app.services.business_access import BUSINESS_MODES, can_use_business_mode

BUCKETS = ("ACTION_REQUIRED", "WAITING_EXTERNAL", "UPCOMING", "AFTER_VIEWING", "HISTORY")


def _allowed(db: Session, user: models.User, mode: str) -> bool:
    return can_use_business_mode(user, mode)


def available_modes(db: Session, user: models.User) -> list[str]:
    """Opening a workspace never grants access to another user's resources."""
    return [mode for mode in BUSINESS_MODES if _allowed(db, user, mode)]


def _scope(db: Session, user_id: int, mode: str):
    if mode == "customer":
        # VN rental tenant bridge removed with guest_dang_thue strip (JP fork).
        # Customer mode retained in BUSINESS_MODES for shared infra but scopes to
        # zero contracts here; JP replaces this surface.
        contract_ids: list[int] = []
        return (
            models.ViewingAppointment.guest_id == user_id,
            models.RentalJourney.customer_id == user_id,
            models.Reservation.guest_user_id == user_id,
            models.Contract.id.in_(contract_ids or [-1]),
            models.Invoice.contract_id.in_(contract_ids or [-1]),
        )
    if mode == "sale":
        room_ids = db.query(models.Room.id).join(models.Building).filter(
            or_(models.Room.managed_by_sale_id == user_id, models.Building.sale_id == user_id)
        )
        house_ids = db.query(models.House.id).filter(models.House.host_id == user_id)
        contract_ids = db.query(models.Contract.id).filter(
            models.Contract.room_id.in_(room_ids)
        )
        return (
            or_(models.ViewingAppointment.room_id.in_(room_ids), models.ViewingAppointment.house_id.in_(house_ids)),
            models.RentalJourney.sale_id == user_id,
            models.Reservation.sale_id == user_id,
            models.Contract.id.in_(contract_ids),
            models.Invoice.contract_id.in_(contract_ids),
        )
    room_ids = db.query(models.Room.id).join(models.Building).filter(
        or_(models.Room.owner_id == user_id, models.Building.host_id == user_id)
    )
    house_ids = db.query(models.House.id).filter(models.House.host_id == user_id)
    contract_ids = db.query(models.Contract.id).filter(
        or_(models.Contract.host_id == user_id, models.Contract.room_id.in_(room_ids))
    )
    return (
        or_(models.ViewingAppointment.room_id.in_(room_ids), models.ViewingAppointment.house_id.in_(house_ids)),
        models.RentalJourney.owner_id == user_id,
        models.Reservation.host_id == user_id,
        models.Contract.id.in_(contract_ids),
        or_(models.Invoice.host_id == user_id, models.Invoice.contract_id.in_(contract_ids)),
    )


def _appointment_bucket(status: str, mode: str) -> str:
    if status in {"cancelled", "rejected", "lost", "locked"}:
        return "HISTORY"
    if status == "approved":
        return "UPCOMING"
    if status == "completed":
        return "AFTER_VIEWING"
    if status in {"awaiting_guest", "cho_khach_chon_gio"}:
        return "ACTION_REQUIRED" if mode == "customer" else "WAITING_EXTERNAL"
    return "ACTION_REQUIRED" if mode in {"sale", "owner"} else "WAITING_EXTERNAL"


def _journey_bucket(status: str, mode: str) -> str:
    if status in {"COMPLETED", "CANCELLED", "CUSTOMER_DECLINED", "DISPUTED"}:
        return "HISTORY"
    if status in {"CUSTOMER_INTERESTED", "CONTRACT_READY", "DEPOSITS_PENDING", "CUSTOMER_CONFIRMATION_PENDING"}:
        return "ACTION_REQUIRED" if mode == "customer" and status != "CUSTOMER_INTERESTED" else "AFTER_VIEWING"
    return "AFTER_VIEWING"


def _reservation_bucket(status: str, mode: str) -> str:
    """Map the existing short-stay lifecycle without inventing new commands."""
    if status in {"cancelled", "rejected", "checked_out", "no_show"}:
        return "HISTORY"
    if status in {"approved", "checked_in"}:
        return "UPCOMING"
    # A guest waits for host/Sale approval; operational roles have a pending
    # request to handle.  This follows the legacy Reservation lifecycle.
    return "WAITING_EXTERNAL" if mode == "customer" else "ACTION_REQUIRED"


def _contract_bucket(status: str, mode: str) -> str:
    if status in {"expired", "terminated", "cancelled"}:
        return "HISTORY"
    if status == "draft":
        return "WAITING_EXTERNAL" if mode == "customer" else "ACTION_REQUIRED"
    # Active stay is downstream of viewing/contracting and remains visible in
    # the shared Activity vocabulary without introducing a sixth bucket in P03.
    return "AFTER_VIEWING"


def _invoice_bucket(status: str, mode: str) -> str:
    if status in {"paid", "cancelled"}:
        return "HISTORY"
    if status == "draft":
        return "WAITING_EXTERNAL" if mode == "customer" else "ACTION_REQUIRED"
    if status in {"sent", "issued", "partially_paid", "overdue"}:
        return "ACTION_REQUIRED" if mode == "customer" else "WAITING_EXTERNAL"
    return "WAITING_EXTERNAL"


def summary(db: Session, claims: dict, *, mode: str) -> dict:
    user = db.get(models.User, claims["sub"])
    if user is None or not _allowed(db, user, mode):
        raise HTTPException(403, "Chế độ Hoạt động chưa được cấp cho tài khoản này")
    (
        appointment_filter,
        journey_filter,
        reservation_filter,
        contract_filter,
        invoice_filter,
    ) = _scope(db, user.id, mode)
    # Aggregate in SQL instead of materialising every row merely to paint five
    # counters. Activity is a hub and this endpoint sits on the first render;
    # keeping it bounded prevents a large owner's appointment history from
    # becoming an accidental unbounded dashboard query.
    appointments = (
        db.query(models.ViewingAppointment.status, func.count(models.ViewingAppointment.id))
        .filter(appointment_filter)
        .group_by(models.ViewingAppointment.status)
        .all()
    )
    journeys = (
        db.query(models.RentalJourney.status, func.count(models.RentalJourney.id))
        .filter(journey_filter)
        .group_by(models.RentalJourney.status)
        .all()
    )
    reservations = (
        db.query(models.Reservation.status, func.count(models.Reservation.id))
        .filter(reservation_filter)
        .group_by(models.Reservation.status)
        .all()
    )
    contracts = (
        db.query(models.Contract.status, func.count(models.Contract.id))
        .filter(contract_filter)
        .group_by(models.Contract.status)
        .all()
    )
    invoices = (
        db.query(models.Invoice.status, func.count(models.Invoice.id))
        .filter(invoice_filter)
        .group_by(models.Invoice.status)
        .all()
    )
    counters = {bucket: 0 for bucket in BUCKETS}
    long_term_counters = {bucket: 0 for bucket in BUCKETS}
    viewing_total = 0
    journey_total = 0
    reservation_total = 0
    short_stay = {
        "total": 0,
        "pending": 0,
        "confirmed": 0,
        "checked_in": 0,
        "history": 0,
    }
    contract_total = 0
    invoice_total = 0
    for status, count in appointments:
        count = int(count)
        bucket = _appointment_bucket(status or "pending", mode)
        counters[bucket] += count
        long_term_counters[bucket] += count
        viewing_total += count
    for status, count in journeys:
        count = int(count)
        bucket = _journey_bucket(status or "", mode)
        counters[bucket] += count
        long_term_counters[bucket] += count
        journey_total += count
    for status, count in reservations:
        count = int(count)
        normalized = status or "pending"
        counters[_reservation_bucket(normalized, mode)] += count
        reservation_total += count
        short_stay["total"] += count
        if normalized == "pending":
            short_stay["pending"] += count
        elif normalized == "approved":
            short_stay["confirmed"] += count
        elif normalized == "checked_in":
            short_stay["checked_in"] += count
        elif normalized in {"cancelled", "rejected", "checked_out", "no_show"}:
            short_stay["history"] += count
    for status, count in contracts:
        count = int(count)
        bucket = _contract_bucket(status or "draft", mode)
        counters[bucket] += count
        long_term_counters[bucket] += count
        contract_total += count
    for status, count in invoices:
        count = int(count)
        bucket = _invoice_bucket(status or "draft", mode)
        counters[bucket] += count
        long_term_counters[bucket] += count
        invoice_total += count
    return {
        "contract_version": "manage-v2.1",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "mode": mode,
        "counters": counters,
        "totals": {
            "viewings": viewing_total,
            "rental_journeys": journey_total,
            "reservations": reservation_total,
            "contracts": contract_total,
            "invoices": invoice_total,
        },
        # Dedicated counters let the UI separate short-stay operations from
        # long-term viewing/contracts without guessing from the mixed buckets.
        # Existing clients ignore this additive object.
        "short_stay": short_stay,
        "long_term": {
            "total": viewing_total + journey_total + contract_total + invoice_total,
            "counters": long_term_counters,
        },
    }


def work_items(db: Session, claims: dict, *, mode: str, bucket: str | None, page: int, page_size: int) -> dict:
    """Stable, non-PII cards for the Activity hub; no legacy command changes."""
    if bucket is not None and bucket not in BUCKETS:
        raise HTTPException(422, "Nhóm công việc không hợp lệ")
    user = db.get(models.User, claims["sub"])
    if user is None or not _allowed(db, user, mode):
        raise HTTPException(403, "Chế độ Hoạt động chưa được cấp cho tài khoản này")
    (
        appointment_filter,
        journey_filter,
        reservation_filter,
        contract_filter,
        invoice_filter,
    ) = _scope(db, user.id, mode)
    cards: list[dict] = []
    for item in db.query(models.ViewingAppointment).filter(appointment_filter).all():
        item_bucket = _appointment_bucket(item.status or "pending", mode)
        if bucket and item_bucket != bucket:
            continue
        cards.append({
            "id": f"viewing:{item.id}", "kind": "VIEWING", "bucket": item_bucket,
            "stage": item.status or "pending", "status_code": item.status or "pending",
            "status_tone": "warning" if item_bucket == "ACTION_REQUIRED" else "neutral",
            "title": "Lịch xem nhà", "subtitle": f"{item.booking_date} · {item.booking_time}",
            "timing": {"business_date": item.booking_date, "slot": item.booking_time},
            "needs_action": item_bucket == "ACTION_REQUIRED", "next_actor": mode,
            "allowed_actions": [], "detail_route": f"/viewing-appointments/{item.id}",
            "aggregate_version": 1,
        })
    payment_rows = db.query(models.RentalJourneyPayment).join(models.RentalJourney).filter(journey_filter).all()
    payments: dict[int, dict[str, models.RentalJourneyPayment]] = {}
    for payment in payment_rows:
        payments.setdefault(payment.journey_id, {})[payment.kind] = payment
    for item in db.query(models.RentalJourney).filter(journey_filter).all():
        item_bucket = _journey_bucket(item.status or "", mode)
        if bucket and item_bucket != bucket:
            continue
        own = payments.get(item.id, {})
        role = "owner" if mode == "owner" else mode
        actions = rental_journey_policy.available_actions(
            actor=role, status=item.status, has_contract=bool(item.contract_urls),
            has_app_proof=bool(own.get("APP_DEPOSIT") and own["APP_DEPOSIT"].proof_urls),
            has_owner_proof=bool(own.get("OWNER_DEPOSIT") and own["OWNER_DEPOSIT"].proof_urls),
            owner_proof_acknowledged=bool(own.get("OWNER_DEPOSIT") and own["OWNER_DEPOSIT"].acknowledged_at),
        )
        cards.append({
            "id": f"rental_journey:{item.id}", "kind": "RENTAL_JOURNEY", "bucket": item_bucket,
            "stage": item.status, "status_code": item.status,
            "status_tone": "warning" if actions else "neutral",
            "title": "Hồ sơ thuê dài hạn", "subtitle": f"Hồ sơ #{item.id}",
            "timing": {"updated_at": item.updated_at.isoformat() if item.updated_at else None},
            "needs_action": bool(actions), "next_actor": mode,
            "allowed_actions": actions, "detail_route": f"/rental-journeys/{item.id}",
            "aggregate_version": 1,
        })
    for item in db.query(models.Reservation).filter(reservation_filter).all():
        item_bucket = _reservation_bucket(item.status or "pending", mode)
        if bucket and item_bucket != bucket:
            continue
        cards.append({
            "id": f"reservation:{item.id}", "kind": "RESERVATION", "bucket": item_bucket,
            "stage": item.status or "pending", "status_code": item.status or "pending",
            "status_tone": "warning" if item_bucket == "ACTION_REQUIRED" else "neutral",
            "title": "Đặt phòng ngắn hạn",
            "subtitle": f"{item.check_in_date} → {item.check_out_date}",
            "timing": {"check_in_date": item.check_in_date, "check_out_date": item.check_out_date},
            "needs_action": item_bucket == "ACTION_REQUIRED", "next_actor": mode,
            "allowed_actions": [], "detail_route": f"/reservations/{item.id}",
            "aggregate_version": 1,
        })
    for item in db.query(models.Contract).filter(contract_filter).all():
        item_bucket = _contract_bucket(item.status or "draft", mode)
        if bucket and item_bucket != bucket:
            continue
        cards.append({
            "id": f"contract:{item.id}", "kind": "CONTRACT", "bucket": item_bucket,
            "stage": item.status or "draft", "status_code": item.status or "draft",
            "status_tone": "warning" if item_bucket == "ACTION_REQUIRED" else "neutral",
            "title": "Hợp đồng thuê", "subtitle": f"{item.start_date} → {item.end_date}",
            "timing": {"start_date": item.start_date, "end_date": item.end_date},
            "needs_action": item_bucket == "ACTION_REQUIRED", "next_actor": mode,
            "allowed_actions": [], "detail_route": f"/contracts/{item.id}",
            "aggregate_version": 1,
        })
    for item in db.query(models.Invoice).filter(invoice_filter).all():
        item_bucket = _invoice_bucket(item.status or "draft", mode)
        if bucket and item_bucket != bucket:
            continue
        # Customer invoice details live inside the authenticated contract
        # profile; host/Sale use the existing invoice detail screen.
        detail_route = (
            f"/contracts/{item.contract_id}"
            if mode == "customer"
            else f"/invoices/{item.id}"
        )
        cards.append({
            "id": f"invoice:{item.id}", "kind": "INVOICE", "bucket": item_bucket,
            "stage": item.status or "draft", "status_code": item.status or "draft",
            "status_tone": "warning" if item_bucket == "ACTION_REQUIRED" else "neutral",
            "title": "Hóa đơn thuê", "subtitle": f"Hạn {item.due_date}",
            "timing": {"due_date": item.due_date, "period_start": item.period_start, "period_end": item.period_end},
            "needs_action": item_bucket == "ACTION_REQUIRED", "next_actor": mode,
            "allowed_actions": [], "detail_route": detail_route,
            "aggregate_version": 1,
        })
    cards.sort(key=lambda value: (not value["needs_action"], value["id"]))
    total = len(cards)
    selected = cards[(page - 1) * page_size: page * page_size]
    return {"contract_version": "manage-v2.1", "generated_at": datetime.utcnow().isoformat() + "Z", "mode": mode, "bucket": bucket, "data": selected, "pagination": {"page": page, "page_size": page_size, "total_items": total, "total_pages": (total + page_size - 1) // page_size}}


def timeline(db: Session, claims: dict, *, mode: str, limit: int) -> dict:
    """Read-only audit timeline.  Event payloads remain server-authored."""
    user = db.get(models.User, claims["sub"])
    if user is None or not _allowed(db, user, mode):
        raise HTTPException(403, "Chế độ Hoạt động chưa được cấp cho tài khoản này")
    (
        _appointment_filter,
        journey_filter,
        _reservation_filter,
        _contract_filter,
        _invoice_filter,
    ) = _scope(db, user.id, mode)
    journey_ids = [item.id for item in db.query(models.RentalJourney.id).filter(journey_filter).all()]
    events = db.query(models.RentalJourneyEvent).filter(models.RentalJourneyEvent.journey_id.in_(journey_ids or [-1])).order_by(models.RentalJourneyEvent.created_at.desc()).limit(limit).all()
    return {"contract_version": "manage-v2.1", "generated_at": datetime.utcnow().isoformat() + "Z", "mode": mode, "data": [{"id": f"journey_event:{event.id}", "kind": "RENTAL_JOURNEY_EVENT", "event_type": event.event_type, "journey_id": event.journey_id, "occurred_at": event.created_at.isoformat(), "payload": event.payload or {}} for event in events]}
