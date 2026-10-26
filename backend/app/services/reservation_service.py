"""Reservation service — create / approve / reject / check-in / check-out / cancel.

Concurrent-booking safety:
    Phase 01h installed `EXCLUDE USING gist` on
    reservations(room_id, daterange(check_in_date, check_out_date, '[)'))
    WHERE status IN ('pending','approved','checked_in') — see migration
    `0011_excl_reservation_overlap`. Postgres rejects overlapping
    INSERTs at the DB layer even under true concurrency.

    The app-level overlap check below is preserved so the API returns a
    400 with a Vietnamese error message instead of leaking a 500
    IntegrityError. On SQLite dev environments the DB-level constraint
    is skipped (no EXCLUDE/gist) so the app-level check is the sole
    guard — acceptable for single-writer dev workflows.

Cancel policy v1 (BA D10 sealed — rigid 24h):
    >24h before check-in → refund 100%
    0–24h before check-in → refund 50%
    after check-in       → refund 0%
"""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.reservation_repository import ReservationRepository
from app.repositories.room_repository import RoomRepository
from app.services import (
    availability_service,
    chiem_dung_service,
    khai_bao_service,
    pricing_service,
    sale_phu_trach,
)

CANCEL_POLICY_V1 = {
    "version": "v1",
    "rigid_24h": True,
    "refund_full_hours_before_checkin": 24,
    "refund_partial_pct": 0.5,
}

# Statuses considered active for overlap/calendar purposes.
ACTIVE_STATUSES = ("pending", "approved", "checked_in")


def _ngay(v) -> date:
    """Ngày dạng `date`, dù cột trả về str (SQLite) hay date (Postgres).

    Cột `check_in_date` khai String trong ORM nhưng là `date` dưới Postgres —
    di sản. Mọi chỗ so ngày phải đi qua đây, không thì test xanh mà prod đỏ.
    """
    if isinstance(v, date):
        return v
    return datetime.strptime(str(v)[:10], "%Y-%m-%d").date()


def _validate_dates(check_in: str, check_out: str) -> int:
    """Return night count; raise on invalid order."""
    ci = pricing_service.parse_iso_date(check_in)
    co = pricing_service.parse_iso_date(check_out)
    if co <= ci:
        raise HTTPException(
            status_code=400,
            detail="check_out_date phải sau check_in_date",
        )
    return (co - ci).days


def _compute_total(
    db: Session, host_id: int, room: models.Room, check_in: str, check_out: str
) -> float:
    """Sum of nightly prices for each stay date (check_out exclusive)."""
    ci = pricing_service.parse_iso_date(check_in)
    co = pricing_service.parse_iso_date(check_out)
    total = 0.0
    d = ci
    while d < co:
        total += pricing_service.resolve_price(db, host_id, room, d)
        d += timedelta(days=1)
    return total


def create_reservation(
    db: Session,
    host_id: int,
    payload: dict,
    actor_id: int,
    source: str = "manual",
) -> models.Reservation:
    """Validate, check overlap, snapshot policy, insert. Caller commits."""
    if payload.get("booking_mode") is not None:
        from app.services import short_stay_service
        return short_stay_service.create(db, host_id, payload, actor_id, source)
    if payload.get("check_in_at") or payload.get("check_out_at"):
        raise HTTPException(422, "Vui lòng chọn hình thức lưu trú")
    if not payload.get("check_in_date") or not payload.get("check_out_date"):
        raise HTTPException(422, "Vui lòng chọn ngày nhận và trả phòng")
    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(payload["room_id"])
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")

    nights = _validate_dates(payload["check_in_date"], payload["check_out_date"])

    # App-level overlap check (Phase 01 TODO: replace with DB exclusion constraint).
    res_repo = ReservationRepository(db, host_id)
    overlapping = res_repo.find_overlapping(
        room_id=room.id,
        check_in=payload["check_in_date"],
        check_out=payload["check_out_date"],
    )
    if overlapping:
        raise HTTPException(
            status_code=409,
            detail="Phòng đã có đặt khác trong khoảng này",
        )

    total = _compute_total(
        db, host_id, room, payload["check_in_date"], payload["check_out_date"]
    )

    # Phase 04: dual-write FK alongside legacy `source` string. Migration 0018
    # enforces NOT NULL on source_id — every INSERT path must resolve a source.
    from app.services import source_service
    source_id = source_service.resolve_default_source_id(db, host_id, source)

    record = models.Reservation(
        host_id=host_id,
        room_id=room.id,
        guest_user_id=payload.get("guest_user_id"),
        guest_name=payload["guest_name"],
        guest_phone=payload.get("guest_phone", ""),
        guest_email=payload.get("guest_email"),
        check_in_date=payload["check_in_date"],
        check_out_date=payload["check_out_date"],
        nights=nights,
        total_amount=total,
        status="pending",
        cancel_policy_snapshot=json.dumps(CANCEL_POLICY_V1),
        source=source,
        source_id=source_id,
        note=payload.get("note"),
    )
    # Quote the globally-administered primary deposit once.  This is additive:
    # the existing ``deposit_paid`` semantics and approval flow do not change.
    from app.services import activity_deposit_policy_service

    activity_deposit_policy_service.apply_short_stay_snapshot(db, record)
    db.add(record)
    db.flush()

    # Giữ chỗ trên DÒNG THỜI GIAN CHUNG của phòng (R4). Kiểm chồng lấn ở trên
    # chỉ nhìn `reservations` của CÙNG chủ nhà, nên nó không thấy hợp đồng dài
    # hạn đang chạy — mà hai kênh dùng chung một cái phòng.
    try:
        chiem_dung_service.ghi(
            db,
            room_id=room.id,
            tu_ngay=_ngay(record.check_in_date),
            den_ngay=_ngay(record.check_out_date),
            kenh="ngan_han",
            nguon=models.RoomChiemDung.RESERVATION,
            nguon_id=record.id,
        )
    except chiem_dung_service.TrungLich as e:
        raise HTTPException(status_code=409, detail=e.message) from e

    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=record.id,
        action="create",
        after={"status": "pending", "total_amount": total},
    )
    return record


def _ghi_giao_dich(db: Session, res: models.Reservation) -> None:
    """Chủ nhà duyệt đơn → ghi một GIAO DỊCH đã xác nhận cho sale phụ trách.

    Vì sao không đếm thẳng `reservations`: đơn đặt phòng là quan hệ khách ↔ chủ
    nhà, không lưu SALE nào dẫn được deal này về. Con số trên trang cá nhân sale
    cần đúng chỗ đó. `deals` là sổ cái, `reservations` là cơ chế đặt.

    Sale không chạm được vào đường này: khách tạo đơn, chủ nhà duyệt.
    Phòng chưa gán sale (`managed_by_sale_id` NULL) thì vẫn ghi, chỉ là không
    ghi công cho ai — để tổng giao dịch của chủ nhà vẫn đủ.
    """
    room = db.get(models.Room, res.room_id) if res.room_id else None
    if room is None or not res.guest_user_id:
        return
    owner_id = sale_phu_trach.chu_cua_phong(db, room)
    if owner_id is None:
        return

    # Sale của TOÀ trước, sale riêng của phòng sau — xem `sale_phu_trach`.
    sale_id = sale_phu_trach.sale_cua_phong(db, room)
    da_co = (
        db.query(models.Deal)
        .filter(
            models.Deal.room_id == room.id,
            models.Deal.customer_id == res.guest_user_id,
            models.Deal.status == "confirmed",
        )
        .first()
    )
    # Duyệt lại đơn của cùng khách cho cùng phòng không được đếm thành hai.
    if da_co is not None:
        return

    now = datetime.utcnow()
    db.add(
        models.Deal(
            room_id=room.id,
            owner_id=owner_id,
            sale_id=None if sale_id == res.guest_user_id else sale_id,
            customer_id=res.guest_user_id,
            deal_type="rent",
            amount=int(room.base_price or 0),
            status="confirmed",
            created_at=now,
            confirmed_at=now,
            confirmed_by=owner_id,
        )
    )


def approve(
    db: Session, host_id: int, reservation_id: int, actor_id: int
) -> models.Reservation:
    """pending → approved + mark Availability rows."""
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if res.status != "pending":
        raise HTTPException(
            status_code=400,
            detail="Chỉ duyệt được đơn đang chờ xác nhận",
        )
    res.status = "approved"
    if not res.booking_mode:
        availability_service.mark_reservation_days(db, res)
        _ghi_giao_dich(db, res)
    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="approve",
        after={"status": "approved"},
    )
    if res.booking_mode:
        from app.services.short_stay_service import notify
        notify(db, res)
    return res


def reject(
    db: Session,
    host_id: int,
    reservation_id: int,
    reason: str,
    actor_id: int,
) -> models.Reservation:
    """pending → rejected, frees no calendar slot (none reserved yet)."""
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if res.status != "pending":
        raise HTTPException(
            status_code=400,
            detail="Chỉ từ chối được đơn đang chờ duyệt",
        )
    res.status = "rejected"
    res.rejection_reason = reason
    # Đơn bị từ chối thì thôi giữ chỗ — nếu không phòng "bận" vì một đơn không
    # bao giờ tới.
    chiem_dung_service.go(db, models.RoomChiemDung.RESERVATION, res.id)
    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="reject",
        after={"status": "rejected", "reason": reason},
    )
    if res.booking_mode:
        from app.services.short_stay_service import notify
        notify(db, res)
    return res


def check_in(
    db: Session, host_id: int, reservation_id: int, actor_id: int
) -> models.Reservation:
    """approved → checked_in + auto-create khai báo tạm trú record."""
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if res.status != "approved":
        raise HTTPException(
            status_code=400,
            detail="Chỉ nhận phòng được khi đơn đã duyệt",
        )
    if res.booking_mode:
        from app.services.short_stay_service import local_now
        if not res.check_in_at <= local_now() < res.check_out_at:
            raise HTTPException(409, "Chỉ nhận phòng trong thời gian đã đặt")
    res.status = "checked_in"
    khai_bao_service.auto_create_for_reservation(db, res)
    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="check_in",
        after={"status": "checked_in"},
    )
    if res.booking_mode:
        from app.services.short_stay_service import notify
        notify(db, res)
    return res


def check_out(
    db: Session, host_id: int, reservation_id: int, actor_id: int
) -> models.Reservation:
    """checked_in → checked_out."""
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if res.status != "checked_in":
        raise HTTPException(
            status_code=400,
            detail="Chỉ trả phòng được khi khách đã nhận phòng",
        )
    res.status = "checked_out"
    if res.booking_mode:
        chiem_dung_service.go(db, models.RoomChiemDung.RESERVATION, res.id)
    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="check_out",
        after={"status": "checked_out"},
    )
    if res.booking_mode:
        from app.services.short_stay_service import notify
        notify(db, res)
    return res


def cancel(
    db: Session,
    host_id: int,
    reservation_id: int,
    actor_id: int,
    reason: Optional[str] = None,
    now: Optional[datetime] = None,
) -> models.Reservation:
    """Compute refund per policy snapshot, transition to cancelled."""
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if res.status not in ("pending", "approved", "checked_in"):
        raise HTTPException(
            status_code=400,
            detail=f"Không huỷ được đơn ở trạng thái {res.status}",
        )

    if res.booking_mode:
        from app.services.short_stay_service import cancellation, local_now
        if actor_id == res.guest_user_id and not cancellation(res, now=now):
            raise HTTPException(409, "Đã hết thời hạn tự huỷ. Vui lòng liên hệ nơi lưu trú")
        if res.status == "checked_in":
            raise HTTPException(409, "Khách đang ở; vui lòng trả phòng")
        now = now or local_now()
        # Pay-at-property MVP has no application-collected funds to refund.
        refund_pct = 0.0
    else:
        now = now or datetime.utcnow()
        refund_pct = _refund_pct(res, now)
    refund_amount = round(res.total_amount * refund_pct, 2)

    res.status = "cancelled"
    res.cancelled_at = now - timedelta(hours=7) if res.booking_mode else now
    res.refund_amount = refund_amount
    if reason:
        res.rejection_reason = reason

    # Free up calendar slots (no-op if never approved).
    if not res.booking_mode:
        availability_service.release_reservation_days(db, res)
    chiem_dung_service.go(db, models.RoomChiemDung.RESERVATION, res.id)

    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="cancel",
        after={
            "status": "cancelled",
            "refund_amount": refund_amount,
            "refund_pct": refund_pct,
            "reason": reason,
        },
    )
    if res.booking_mode:
        from app.services.short_stay_service import notify
        notify(db, res)
    return res


def no_show(
    db: Session,
    host_id: int,
    reservation_id: int,
    actor_id: int,
    now: Optional[datetime] = None,
) -> models.Reservation:
    """approved → no_show: tới giờ nhận mà khách không đến.

    Chỉ cho đơn ngắn hạn đã duyệt và chỉ khi khung giờ đã bắt đầu — đánh dấu
    sớm hơn là đoán. Nhả lịch ngay để phòng bán lại được phần còn lại của
    khung; tiền không đụng tới (app chưa thu tiền, cọc nếu có do quầy xử lý).
    """
    res = _get_reservation_or_404(db, host_id, reservation_id)
    if not res.booking_mode:
        raise HTTPException(400, "Chỉ áp dụng cho đơn lưu trú ngắn hạn")
    if res.status != "approved":
        raise HTTPException(400, "Chỉ đánh dấu không đến với đơn đã duyệt, chưa nhận phòng")
    from app.services.short_stay_service import local_now, notify
    if (now or local_now()) < res.check_in_at:
        raise HTTPException(409, "Chưa tới giờ nhận phòng")
    res.status = "no_show"
    chiem_dung_service.go(db, models.RoomChiemDung.RESERVATION, res.id)
    write_change_log(
        db,
        actor_id=actor_id,
        entity_type="reservation",
        entity_id=res.id,
        action="no_show",
        after={"status": "no_show"},
    )
    notify(db, res)
    return res


def _refund_pct(res: models.Reservation, now: datetime) -> float:
    """BA D10 rigid 24h: >24h full, 0-24h 50%, after check-in 0%."""
    if res.status == "checked_in":
        return 0.0
    check_in_dt = datetime.combine(_ngay(res.check_in_date), datetime.min.time())
    hours_until = (check_in_dt - now).total_seconds() / 3600.0
    if hours_until < 0:
        return 0.0
    if hours_until < 24:
        return 0.5
    return 1.0


def _get_reservation_or_404(
    db: Session, host_id: int, reservation_id: int
) -> models.Reservation:
    db.flush()
    res = (db.query(models.Reservation)
           .filter_by(host_id=host_id, id=reservation_id)
           .populate_existing().with_for_update().first())
    if res is None:
        raise HTTPException(status_code=404, detail="Đơn đặt phòng không tồn tại")
    return res
