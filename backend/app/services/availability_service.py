"""Availability + calendar synthesis service (Phase 07).

The calendar shown to the host is a join of three sources:
    1. Explicit Availability rows (blocked/reserved overrides)
    2. Active Reservations covering the day (status in pending/approved/checked_in)
    3. PricingRule resolution for the per-day price

Default state for a day with no override + no reservation is 'available'
at the room.base_price (or resolved base/weekend/holiday rule).
"""

from __future__ import annotations

import calendar as cal
from datetime import date, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.repositories.availability_repository import AvailabilityRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.reservation_repository import ReservationRepository
from app.services import pricing_service


def _days_in_month(month: str) -> list[date]:
    year_s, mon_s = month.split("-")
    year, mon = int(year_s), int(mon_s)
    _, last_day = cal.monthrange(year, mon)
    return [date(year, mon, d) for d in range(1, last_day + 1)]


def _building_name_for_room(db: Session, room: models.Room) -> str:
    b = db.get(models.Building, room.building_id)
    return b.name if b else ""


def _room_or_404(db: Session, host_id: int, room_id: int) -> models.Room:
    repo = RoomRepository(db, host_id)
    room = repo.get(room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    return room


def get_calendar(
    db: Session, host_id: int, room_id: int, month: str
) -> dict:
    """Return per-day status + price for a (room, month)."""
    room = _room_or_404(db, host_id, room_id)
    return _build_room_calendar(db, host_id, room, month)


def get_unified_calendar(
    db: Session, host_id: int, month: str
) -> dict:
    """All host rooms × month — for the multi-room view."""
    room_repo = RoomRepository(db, host_id)
    rooms = room_repo.list()
    rows = []
    for room in rooms:
        day_data = _build_room_calendar(db, host_id, room, month)
        rows.append({
            "room_id": room.id,
            "room_code": room.code,
            "building_name": _building_name_for_room(db, room),
            "days": day_data["days"],
        })
    return {"month": month, "rows": rows}


def _build_room_calendar(
    db: Session, host_id: int, room: models.Room, month: str
) -> dict:
    """Core calendar synthesis — shared by single-room and unified views."""
    avail_repo = AvailabilityRepository(db, host_id)
    res_repo = ReservationRepository(db, host_id)
    overrides = {
        row.date: row for row in avail_repo.list_for_room_month(room.id, month)
    }
    reservations = res_repo.list_active_for_rooms_month([room.id], month)

    def reservation_at(d: date) -> Optional[models.Reservation]:
        iso = d.isoformat()
        for r in reservations:
            if str(r.check_in_date) <= iso < str(r.check_out_date):
                return r
        return None

    days_out = []
    for d in _days_in_month(month):
        iso = d.isoformat()
        override = overrides.get(iso)
        reservation = reservation_at(d)
        if override is not None and override.status == "blocked":
            status = "blocked"
            reservation_id = None
            note = override.note
        elif reservation is not None:
            status = "reserved"
            reservation_id = reservation.id
            note = None
        else:
            status = "available"
            reservation_id = None
            note = override.note if override else None
        price = pricing_service.resolve_price(db, host_id, room, d)
        days_out.append({
            "date": iso,
            "status": status,
            "price_per_night": price,
            "reservation_id": reservation_id,
            "note": note,
        })

    return {
        "room_id": room.id,
        "room_code": room.code,
        "month": month,
        "days": days_out,
        "base_price": float(room.base_price or 0),
    }


def block_range(
    db: Session,
    host_id: int,
    room_id: int,
    start_date: str,
    end_date: str,
    action: str,
    note: Optional[str] = None,
) -> int:
    """Block or unblock an inclusive date range. Returns rows touched.

    Blocking a date that's already reserved is rejected (409) — host must
    cancel the reservation first.
    """
    room = _room_or_404(db, host_id, room_id)
    # Serialize legacy whole-day blocks with precise short-stay booking writers.
    db.query(models.Room).filter_by(id=room.id).with_for_update().first()
    if action not in ("block", "unblock"):
        raise HTTPException(status_code=400, detail="action phải là block|unblock")

    start = pricing_service.parse_iso_date(start_date)
    end = pricing_service.parse_iso_date(end_date)
    if end < start:
        raise HTTPException(status_code=400, detail="end_date phải >= start_date")

    res_repo = ReservationRepository(db, host_id)
    if action == "block":
        # Reject if any active reservation overlaps the requested range.
        end_exclusive = (end + timedelta(days=1)).isoformat()
        overlapping = res_repo.find_overlapping(
            room_id=room.id,
            check_in=start.isoformat(),
            check_out=end_exclusive,
        )
        if overlapping:
            raise HTTPException(
                status_code=409,
                detail="Khoảng này đã có đặt phòng — huỷ đặt phòng trước",
            )

    avail_repo = AvailabilityRepository(db, host_id)
    touched = 0
    d = start
    while d <= end:
        iso = d.isoformat()
        row = avail_repo.get_by_room_date(room.id, iso)
        if action == "block":
            if row is None:
                row = models.Availability(
                    host_id=host_id,
                    room_id=room.id,
                    date=iso,
                    status="blocked",
                    note=note,
                )
                db.add(row)
            else:
                row.status = "blocked"
                if note is not None:
                    row.note = note
            touched += 1
        else:
            # unblock: revert to 'available' (delete the row if no reservation tie)
            if row is not None and row.reservation_id is None:
                db.delete(row)
                touched += 1
        d += timedelta(days=1)

    db.flush()
    return touched


def mark_reservation_days(
    db: Session, reservation: models.Reservation
) -> None:
    """Stamp Availability rows for an approved reservation's nights."""
    start = pricing_service.parse_iso_date(reservation.check_in_date)
    end_excl = pricing_service.parse_iso_date(reservation.check_out_date)
    avail_repo = AvailabilityRepository(db, reservation.host_id)
    d = start
    while d < end_excl:
        iso = d.isoformat()
        row = avail_repo.get_by_room_date(reservation.room_id, iso)
        if row is None:
            row = models.Availability(
                host_id=reservation.host_id,
                room_id=reservation.room_id,
                date=iso,
                status="reserved",
                reservation_id=reservation.id,
            )
            db.add(row)
        else:
            row.status = "reserved"
            row.reservation_id = reservation.id
        d += timedelta(days=1)
    db.flush()


def release_reservation_days(
    db: Session, reservation: models.Reservation
) -> None:
    """Free Availability rows tied to a cancelled/rejected reservation."""
    avail_repo = AvailabilityRepository(db, reservation.host_id)
    rows = avail_repo.list_for_reservation(reservation.id)
    for row in rows:
        db.delete(row)
    db.flush()
