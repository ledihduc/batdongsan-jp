"""Khung giờ đặt xem nhà (viewing-appointment slots).

Khác với `availability_service` (lịch phòng/đặt phòng cho thuê). Đây là slot cho
tính năng "đặt lịch xem nhà": khách chọn 1 khung giờ, chủ nhà duyệt.

Nguồn sự thật cho:
  - Bộ slot chuẩn (canonical): 12 khung 1 tiếng, 08:00 → 20:00.
  - Cấu hình chủ nhà mở nhận (houses.availability_config); null = mở mặc định.
  - Tính slot cho 1 ngày: open / taken (đã bị chiếm) / ẩn (đóng hoặc quá giờ).

Slot bị chiếm = có ViewingAppointment status ∈ {pending, approved, locked}
(đặt chưa duyệt vẫn khoá slot). Quá khứ bị loại (theo giờ VN, UTC+7).
"""

from __future__ import annotations

from datetime import date as date_cls
from datetime import datetime, timedelta
from typing import Any, Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app import models

# Trạng thái chiếm slot — trùng với partial unique index (migration 0041).
ACTIVE_STATUSES = ("pending", "approved", "locked")

# Bộ slot chuẩn: 12 khung 1 tiếng 08:00–20:00. 'HH:MM-HH:MM' (không khoảng trắng).
CANONICAL_SLOTS: list[str] = [f"{h:02d}:00-{h + 1:02d}:00" for h in range(8, 20)]
_SLOT_SET = set(CANONICAL_SLOTS)
_SLOT_INDEX = {s: i for i, s in enumerate(CANONICAL_SLOTS)}

# 0 = Thứ Hai ... 6 = Chủ Nhật (khớp date.weekday()).
ALL_WEEKDAYS = [0, 1, 2, 3, 4, 5, 6]


def default_config() -> dict[str, Any]:
    return {"version": 1, "weekdays": list(ALL_WEEKDAYS), "slots": list(CANONICAL_SLOTS)}


def vn_now() -> datetime:
    """Thời điểm hiện tại theo giờ VN (UTC+7). Backend lưu UTC."""
    return datetime.utcnow() + timedelta(hours=7)


def parse_date(date_str: str) -> Optional[date_cls]:
    try:
        return datetime.strptime((date_str or "").strip(), "%Y-%m-%d").date()
    except (ValueError, AttributeError):
        return None


def normalize_slot(raw: str) -> str:
    """Chuẩn hoá slot: bỏ mọi khoảng trắng ('09:00 - 10:00' → '09:00-10:00')."""
    return (raw or "").replace(" ", "")


def sanitize_config(payload: Any) -> dict[str, Any]:
    """Làm sạch cấu hình chủ nhà gửi lên → chỉ giữ weekday 0..6 + slot hợp lệ.

    Trả cấu hình chuẩn hoá (dedup + sort theo bộ chuẩn). Rỗng vẫn cho phép lưu
    (chủ nhà tạm không nhận lịch) — FE cảnh báo.
    """
    payload = payload or {}
    raw_weekdays = payload.get("weekdays", [])
    raw_slots = payload.get("slots", [])

    weekdays: list[int] = []
    if isinstance(raw_weekdays, list):
        for w in raw_weekdays:
            try:
                iw = int(w)
            except (ValueError, TypeError):
                continue
            if 0 <= iw <= 6 and iw not in weekdays:
                weekdays.append(iw)
    weekdays.sort()

    slots: list[str] = []
    if isinstance(raw_slots, list):
        for s in raw_slots:
            cs = normalize_slot(str(s))
            if cs in _SLOT_SET and cs not in slots:
                slots.append(cs)
    slots.sort(key=lambda s: _SLOT_INDEX[s])

    return {"version": 1, "weekdays": weekdays, "slots": slots}


def get_config(house: Optional[models.House]) -> dict[str, Any]:
    """Cấu hình hiệu lực của 1 nhà (đã cấu hình → dùng, chưa → mặc định mở).

    `None` = lịch đặt thẳng vào PHÒNG chưa gắn tin. Chưa có nơi nào để chủ nhà
    cấu hình khung giờ cho phòng lẻ, nên mở mặc định — đóng hết thì tính năng
    coi như không tồn tại, mà cấu hình rỗng người dùng cũng không hiểu vì sao.
    """
    cfg = getattr(house, "availability_config", None) if house is not None else None
    if not cfg or not isinstance(cfg, dict):
        return default_config()
    return sanitize_config(cfg)


def _taken_slots(
    db: Session,
    house_id: Optional[int],
    date_str: str,
    room_id: Optional[int] = None,
) -> set[str]:
    """Khung giờ đã bị chiếm — tính theo CẢ tin lẫn phòng.

    Một lịch có thể neo vào tin, vào phòng, hoặc cả hai (mig 0095). Chỉ hỏi một
    đầu thì hai khách đặt cùng giờ trên cùng cái phòng — một người đi từ tin,
    một người đi từ trang dự án — đều thấy slot trống.
    """
    dieu_kien = []
    if house_id is not None:
        dieu_kien.append(models.ViewingAppointment.house_id == house_id)
    if room_id is not None:
        dieu_kien.append(models.ViewingAppointment.room_id == room_id)
    if not dieu_kien:
        return set()

    rows = (
        db.query(models.ViewingAppointment.booking_time)
        .filter(
            or_(*dieu_kien),
            models.ViewingAppointment.booking_date == date_str,
            models.ViewingAppointment.status.in_(ACTIVE_STATUSES),
        )
        .all()
    )
    return {normalize_slot(r[0]) for r in rows}


def available_slots(
    db: Session,
    house: Optional[models.House],
    date_str: str,
    room_id: Optional[int] = None,
) -> dict[str, Any]:
    """Danh sách slot cho 1 ngày.

    Trả {"date","weekday","slots":[{"time","status"}]}. status: 'open' | 'taken'.
    Slot đóng (không trong cấu hình) hoặc đã qua giờ → ẩn. Ngày quá khứ → rỗng.
    """
    d = parse_date(date_str)
    if d is None:
        return {"date": date_str, "weekday": None, "slots": []}

    now = vn_now()
    today = now.date()
    if d < today:
        return {"date": date_str, "weekday": d.weekday(), "slots": []}

    cfg = get_config(house)
    weekday = d.weekday()
    if weekday not in cfg["weekdays"]:
        return {"date": date_str, "weekday": weekday, "slots": []}

    cfg_slots = set(cfg["slots"])
    open_slots = [s for s in CANONICAL_SLOTS if s in cfg_slots]
    taken = _taken_slots(
        db, house.id if house is not None else None, date_str, room_id
    )

    out: list[dict[str, Any]] = []
    for slot in open_slots:
        if d == today and int(slot[:2]) <= now.hour:
            continue  # ẩn slot đã bắt đầu (giờ VN)
        out.append({"time": slot, "status": "taken" if slot in taken else "open"})

    return {"date": date_str, "weekday": weekday, "slots": out}


def validate_booking(
    db: Session,
    house: Optional[models.House],
    date_str: str,
    slot: str,
    room_id: Optional[int] = None,
) -> Optional[str]:
    """Kiểm 1 yêu cầu đặt lịch. None nếu hợp lệ, ngược lại mã lỗi:
    'invalid_date' | 'past_date' | 'invalid_slot' | 'slot_closed' | 'slot_taken'.
    """
    d = parse_date(date_str)
    if d is None:
        return "invalid_date"

    now = vn_now()
    if d < now.date():
        return "past_date"

    slot = normalize_slot(slot)
    if slot not in _SLOT_SET:
        return "invalid_slot"

    cfg = get_config(house)
    if d.weekday() not in cfg["weekdays"] or slot not in set(cfg["slots"]):
        return "slot_closed"

    if d == now.date() and int(slot[:2]) <= now.hour:
        return "past_date"

    if slot in _taken_slots(
        db, house.id if house is not None else None, date_str, room_id
    ):
        return "slot_taken"

    return None
