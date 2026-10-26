"""Short-stay prices, policy and inventory; all wall times are Asia/Ho_Chi_Minh."""

from __future__ import annotations

import hashlib
import json
import math
import secrets
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.services import (
    activity_deposit_policy_service,
    chiem_dung_service,
    sale_phu_trach,
    source_service,
)

VN = timezone(timedelta(hours=7))
MODES = {
    "theo_gio": ("Theo giờ", "gio", "giờ", 1),
    "qua_dem": ("Qua đêm", "dem", "đêm", 2),
    "theo_ngay": ("Theo ngày", "ngay", "ngày", 12),
}
STATUSES = {
    "pending": "Chờ duyệt",
    "approved": "Đã xác nhận",
    "rejected": "Đã từ chối",
    "checked_in": "Đã nhận phòng",
    "checked_out": "Đã trả phòng",
    "cancelled": "Đã huỷ",
    "no_show": "Không đến",
}


def local_now():
    return datetime.now(VN).replace(tzinfo=None)


def local_time(value):
    try:
        dt = (
            value
            if isinstance(value, datetime)
            else datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        )
    except (TypeError, ValueError):
        raise HTTPException(422, "Ngày giờ không hợp lệ")
    if dt.tzinfo is None:
        raise HTTPException(422, "Ngày giờ phải có múi giờ, ví dụ +07:00")
    return dt.astimezone(VN).replace(tzinfo=None)


def iso(dt):
    return dt.replace(tzinfo=VN).isoformat() if dt else None


#: Giờ trả phòng của ca QUA ĐÊM và THEO NGÀY — luật nhà, không phải tuỳ chọn.
GIO_TRA_TRUA = 12


def gio_tra(mode, ci, so_don_vi):
    """Giờ trả phòng CHUẨN của một ca, tính từ giờ nhận và số đơn vị đã đặt.

    * Theo giờ: **chẵn tiếng**, làm tròn LÊN. Nhận 14:46 đặt 4 giờ thì trả
      19:00 chứ không phải 18:46 — phần lẻ là của khách, và lịch phòng đọc
      được (không có ô "18:46" lửng lơ giữa lưới giờ).
    * Qua đêm / theo ngày: trả **12:00 trưa**, như mọi khách sạn. Nhận trước
      trưa thì trả trưa CÙNG ngày cuối, nhận sau trưa thì trả trưa hôm sau —
      nếu không, khách vào lúc 1h sáng sẽ được ở 35 tiếng.

    Một chỗ duy nhất tính giờ trả: quầy lễ tân, app khách và bảng giá phải ra
    cùng một con số, lệch nhau một tiếng là cãi nhau lúc trả phòng.
    """
    if mode == "theo_gio":
        tho = ci + timedelta(hours=so_don_vi)
        if tho.minute or tho.second or tho.microsecond:
            tho = tho.replace(minute=0, second=0, microsecond=0) + timedelta(hours=1)
        return tho
    if mode == "qua_dem":
        # Một đêm: vào tối nay trả trưa mai; vào lúc 1h sáng thì trả trưa CÙNG
        # ngày — vẫn là một đêm đó, không phải 35 tiếng.
        ngay = ci.date() + (timedelta(days=1) if ci.hour >= GIO_TRA_TRUA else timedelta())
    else:
        # n ngày = n đêm, trả trưa ngày cuối.
        ngay = ci.date() + timedelta(days=so_don_vi)
    return datetime.combine(ngay, time(GIO_TRA_TRUA))


def validate_stay(mode, start, end, now=None):
    """Kiểm giờ nhận/trả và CHUẨN HOÁ giờ trả theo luật nhà.

    Trả `(giờ nhận, giờ trả đã chuẩn hoá, số đơn vị tính tiền)`. Client gửi giờ
    trả thô (nhận + n giờ) hay giờ trả đã chuẩn đều ra cùng kết quả: số đơn vị
    lấy theo phần NGUYÊN đã dùng, nên phần dư do làm tròn không bị tính tiền
    lần nữa.
    """
    if mode not in MODES:
        raise HTTPException(422, "Hình thức đặt phòng không hợp lệ")
    ci, co = local_time(start), local_time(end)
    if ci < (now or local_now()) or ci > (now or local_now()) + timedelta(days=730):
        raise HTTPException(422, "Giờ nhận phòng phải từ hiện tại đến 2 năm tới")
    if ci.second or ci.microsecond or (co - ci).total_seconds() <= 0:
        raise HTTPException(422, "Giờ trả phải sau giờ nhận; vui lòng chọn đến phút")

    if mode == "theo_gio":
        units = int((co - ci).total_seconds() // 3600)
        if not 1 <= units <= 24:
            raise HTTPException(422, "Theo giờ: đặt từ 1 đến 24 giờ")
    elif mode == "qua_dem":
        units = 1
    else:
        # Số ĐÊM = số ngày lịch giữa nhận và trả. Client cũ gửi bội 24 giờ,
        # client mới gửi mốc 12:00 trưa — cả hai ra cùng con số.
        units = (co.date() - ci.date()).days
        if not 1 <= units <= 30:
            raise HTTPException(422, "Theo ngày: đặt từ 1 đến 30 ngày")

    return ci, gio_tra(mode, ci, units), units


def channel(db, room_id, enabled=True):
    q = db.query(models.RoomKenh).filter_by(room_id=room_id, kenh="ngan_han")
    if enabled:
        q = q.join(models.Room, models.Room.id == models.RoomKenh.room_id).join(
            models.Building, models.Building.id == models.Room.building_id
        )
        q = q.filter(
            models.Building.is_public.is_(True),
            models.Room.status != "maintenance",
            models.RoomKenh.dang_bat.is_(True),
            models.RoomKenh.trang_thai.notin_(models.RoomKenh.KET_THUC),
        )
    return q.first()


def products(k):
    result = []
    if k is None:
        return result
    for mode, (label, suffix, unit, default) in MODES.items():
        rate = getattr(k, f"gia_{mode}", None)
        if (
            rate is None
            or not math.isfinite(rate)
            or not 1 <= rate < 1000000000
            or rate != int(rate)
        ):
            continue
        hours = getattr(k, f"huy_truoc_{suffix}", default)
        hours = default if hours is None else hours
        result.append(
            {
                "booking_mode": mode,
                "label": label,
                "unit": unit,
                "unit_price": rate,
                "free_cancel_hours": hours,
                "cancellation_policy": policy_text(hours),
                "stay_rule": {
                    "theo_gio": "1–24 giờ, trả phòng làm tròn chẵn tiếng",
                    "qua_dem": "Qua đêm, trả phòng 12:00 trưa hôm sau",
                    "theo_ngay": "1–30 ngày, trả phòng 12:00 trưa ngày cuối",
                }[mode],
            }
        )
    return result


def policy_text(hours):
    return f"Huỷ miễn phí đến {hours} giờ trước giờ nhận phòng. Sau thời hạn này, liên hệ nơi lưu trú. Thanh toán tại nơi lưu trú; ứng dụng chưa thu tiền."


def room_public(db, room, k=None):
    building = db.get(models.Building, room.building_id)
    k = k or channel(db, room.id)
    return {
        "room_id": room.id,
        "room_code": room.code,
        "room_type": (k.loai_phong or "Phòng") if k else "Phòng",
        "building_name": building.name,
        "address": building.address,
        "city": building.city,
        "district": building.district,
        "capacity": room.capacity,
        "products": products(k),
        "payment_policy": "Thanh toán tại nơi lưu trú khi nhận phòng",
    }


def busy(db, room_id, ci, co, bo_qua=None):
    """[bo_qua] = id đơn của CHÍNH khách đang đổi giờ — không tự đụng lịch mình."""
    # Date projection is deliberately broad; precise check preserves adjacent slots.
    ceiling = co.date() + (timedelta(days=1) if co.time() != time() else timedelta())
    entries = chiem_dung_service.lich(db, room_id, ci.date(), ceiling)
    for row in entries:
        if (
            bo_qua is not None
            and row.nguon == models.RoomChiemDung.RESERVATION
            and row.nguon_id == bo_qua
        ):
            continue
        a = row.tu_luc or datetime.combine(row.tu_ngay, time())
        b = row.den_luc or datetime.combine(row.den_ngay, time())
        if a < co and ci < b:
            return True
    # Cover legacy rows written without the shared ledger and old manual calendar blocks.
    for r in (
        db.query(models.Reservation)
        .filter(
            models.Reservation.room_id == room_id,
            models.Reservation.status.in_(("pending", "approved", "checked_in")),
            models.Reservation.id != (bo_qua or 0),
        )
        .all()
    ):
        a = r.check_in_at or datetime.combine(
            date.fromisoformat(str(r.check_in_date)), time()
        )
        b = r.check_out_at or datetime.combine(
            date.fromisoformat(str(r.check_out_date)), time()
        )
        if a < co and ci < b:
            return True
    return (
        db.query(models.Availability.id)
        .filter(
            models.Availability.room_id == room_id,
            models.Availability.status == "blocked",
            models.Availability.date >= ci.date().isoformat(),
            models.Availability.date < ceiling.isoformat(),
        )
        .first()
        is not None
    )


def quote(db, room_id, mode, start, end, now=None, bo_qua=None):
    ci, co, units = validate_stay(mode, start, end, now)
    room = db.get(models.Room, room_id)
    k = channel(db, room_id)
    product = next((p for p in products(k) if p["booking_mode"] == mode), None)
    if room is None or product is None:
        raise HTTPException(409, "Phòng chưa mở hình thức lưu trú này hoặc chưa có giá")
    if busy(db, room_id, ci, co, bo_qua=bo_qua):
        raise HTTPException(409, "Phòng đã có lịch trong khoảng thời gian này")
    amount = int(Decimal(str(product["unit_price"])) * units)
    result = {
        **product,
        "room_id": room_id,
        "room_type": k.loai_phong or "Phòng",
        "check_in_at": iso(ci),
        "check_out_at": iso(co),
        "quantity": units,
        "subtotal": amount,
        "fees": 0,
        "total_amount": amount,
        "currency": "VND",
        "payment_policy": "Thanh toán tại nơi lưu trú khi nhận phòng",
        "free_cancel_until": iso(ci - timedelta(hours=product["free_cancel_hours"])),
    }
    # A version of the displayed quote. Not a credential; prevents silent rate/policy changes.
    result["quote_token"] = hashlib.sha256(
        json.dumps(result, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()
    return result


def create(db, host_id, payload, actor_id, source):
    # Lock room before quote and ledger write; DB exclusions also protect external writers.
    room = (
        db.query(models.Room).filter_by(id=payload["room_id"]).with_for_update().first()
    )
    if room is None:
        raise HTTPException(404, "Phòng không tồn tại")
    building = db.get(models.Building, room.building_id)
    if host_id not in (building.host_id, room.owner_id):
        raise HTTPException(404, "Phòng không tồn tại")
    host_id = sale_phu_trach.chu_cua_phong(db, room) or building.host_id
    q = quote(
        db,
        room.id,
        payload["booking_mode"],
        payload.get("check_in_at"),
        payload.get("check_out_at"),
    )
    if payload.get("quote_token") != q["quote_token"]:
        raise HTTPException(
            409,
            "Giá hoặc chính sách đã thay đổi. Vui lòng xem lại giá trước khi xác nhận",
        )
    ci, co = local_time(q["check_in_at"]), local_time(q["check_out_at"])
    ceiling = co.date() + (timedelta(days=1) if co.time() != time() else timedelta())
    code = f"AC-{ci:%y%m%d}-{secrets.token_hex(5).upper()}"
    policy = {
        "version": "short_stay_v1",
        "free_cancel_hours": q["free_cancel_hours"],
        "free_cancel_until": q["free_cancel_until"],
        "text": q["cancellation_policy"],
        "payment": "pay_at_property",
    }
    res = models.Reservation(
        host_id=host_id,
        room_id=room.id,
        guest_user_id=payload.get("guest_user_id"),
        guest_name=payload["guest_name"].strip(),
        guest_phone=payload.get("guest_phone", "").strip(),
        guest_email=payload.get("guest_email"),
        booking_mode=payload["booking_mode"],
        check_in_at=ci,
        check_out_at=co,
        booking_code=code,
        check_in_date=ci.date().isoformat(),
        check_out_date=ceiling.isoformat(),
        nights=max(1, (co.date() - ci.date()).days),
        total_amount=q["total_amount"],
        price_snapshot=json.dumps(q, ensure_ascii=False),
        cancel_policy_snapshot=json.dumps(policy, ensure_ascii=False),
        status="pending",
        source=source,
        source_id=source_service.resolve_default_source_id(db, host_id, source),
        note=payload.get("note"),
        sale_id=payload.get("sale_id"),
        house_id=payload.get("house_id"),
        so_khach=payload.get("so_khach"),
    )
    # Same snapshot contract as overnight reservations.  Future Admin edits
    # cannot rewrite the deposit quoted to a guest who already holds this slot.
    activity_deposit_policy_service.apply_short_stay_snapshot(db, res)
    try:
        db.add(res)
        db.flush()
        chiem_dung_service.ghi(
            db,
            room_id=room.id,
            tu_ngay=ci.date(),
            den_ngay=ceiling,
            tu_luc=ci,
            den_luc=co,
            kenh="ngan_han",
            nguon="reservation",
            nguon_id=res.id,
        )
        write_change_log(
            db,
            actor_id=actor_id,
            entity_type="reservation",
            entity_id=res.id,
            action="create",
            after={
                "status": res.status,
                "booking_code": code,
                "total_amount": res.total_amount,
                # Đủ để dòng lịch sử "Đặt phòng" tự kể lại đã đặt giờ nào.
                "hinh_thuc": res.booking_mode,
                "nhan": iso(ci),
                "tra": iso(co),
                "tong": res.total_amount,
                "so_khach": payload.get("so_khach"),
            },
        )
        notify(db, res)
        db.flush()
    except (IntegrityError, chiem_dung_service.TrungLich) as exc:
        db.rollback()
        if (
            isinstance(exc, IntegrityError)
            and getattr(exc.orig, "pgcode", None) != "23P01"
        ):
            raise
        raise HTTPException(
            409, "Phòng vừa được giữ chỗ. Vui lòng chọn thời gian khác"
        ) from exc
    return res


def cancellation(res, now=None):
    """Khách còn tự huỷ MIỄN PHÍ được không.

    Chỉ đơn đặt qua luồng online mới chụp hạn huỷ (`free_cancel_until`). Đơn vào
    đường khác — vãng lai chủ nhà ghi tại quầy, đơn OTA nhập tay (`agoda`,
    `manual`) — giữ chính sách mặc định không có mốc này. Trước 18/09/2026 hàm
    đọc thẳng `snapshot["free_cancel_until"]` nên MỘT đơn như thế làm 500 cả danh
    sách đơn của chủ nhà (`/api/host/short-stays/reservations`) lẫn trang Quản
    lý. Không có hạn huỷ = khách không tự huỷ được; chủ/sale vẫn huỷ ở quầy.
    """
    try:
        snapshot = json.loads(res.cancel_policy_snapshot or "{}")
    except (TypeError, ValueError):
        return False
    han = snapshot.get("free_cancel_until") if isinstance(snapshot, dict) else None
    if not han or res.check_in_at is None:
        return False
    deadline = local_time(han)
    return (
        res.status in ("pending", "approved")
        and (now or local_now()) <= deadline
        and (now or local_now()) < res.check_in_at
    )


#: Loại thông báo gửi NGƯỜI VẬN HÀNH (chủ phòng + sale) — bấm vào mở màn quầy.
#: Khách nhận `short_stay` và bấm vào mở đơn của chính họ. Tách hai loại vì hai
#: bên mở hai màn khác nhau, app không được đoán theo vai.
LOAI_VAN_HANH = "short_stay_van_hanh"


def notify(db, res):
    """Thông báo trong app cho chủ phòng, sale dẫn khách, và khách.

    Chỉ lưu trong app, không gửi ra ngoài. Tiêu đề đơn mới nói thẳng "Đơn đặt
    phòng mới" thay vì "Chờ duyệt" trơn — người đọc cần biết có VIỆC phải làm,
    không phải một nhãn trạng thái.
    """
    room = db.get(models.Room, res.room_id)
    sale_id = res.sale_id or sale_phu_trach.sale_cua_phong(db, room)
    sale = db.get(models.User, sale_id) if sale_id else None
    khung = (
        f"{MODES[res.booking_mode][0]} · {res.check_in_at:%H:%M %d/%m} – "
        f"{res.check_out_at:%H:%M %d/%m}"
    )
    van_hanh_title = (
        "Đơn đặt phòng mới · chờ duyệt"
        if res.status == "pending"
        else f"Đơn {res.booking_code} · {STATUSES[res.status]}"
    )
    van_hanh_body = " · ".join(
        x
        for x in (
            res.guest_name,
            f"Phòng {room.code}",
            khung,
            f"{res.so_khach} khách" if getattr(res, "so_khach", None) else None,
            res.booking_code,
            f"qua sale {sale.name}" if sale is not None and sale.name else None,
        )
        if x
    )
    van_hanh = {res.host_id, sale_id} - {None}
    for uid in van_hanh:
        db.add(
            models.Notification(
                user_id=uid,
                type=LOAI_VAN_HANH,
                title=van_hanh_title,
                body=van_hanh_body,
                related_id=res.id,
                channel="in_app",
                delivery_status="delivered",
            )
        )
    if res.guest_user_id and res.guest_user_id not in van_hanh:
        db.add(
            models.Notification(
                user_id=res.guest_user_id,
                type="short_stay",
                title=STATUSES[res.status],
                body=f"Đặt phòng {res.booking_code} · Phòng {room.code} · {khung}",
                related_id=res.id,
                channel="in_app",
                delivery_status="delivered",
            )
        )


def response_fields(res):
    if not res.booking_mode:
        return {}
    return {
        "booking_mode": res.booking_mode,
        "booking_code": res.booking_code,
        "check_in_at": iso(res.check_in_at),
        "check_out_at": iso(res.check_out_at),
        # Đơn vãng lai tại quầy / OTA nhập tay không đi qua bước báo giá nên
        # không có giá chụp lúc đặt — cùng họ lỗi với `cancellation` (18/09/2026:
        # một đơn như thế làm 500 cả danh sách đơn của chủ nhà).
        "price_breakdown": json.loads(res.price_snapshot) if res.price_snapshot else {},
        "can_cancel": cancellation(res),
        "status_label": STATUSES.get(res.status, res.status),
    }
