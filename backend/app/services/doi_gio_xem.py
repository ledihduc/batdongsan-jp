"""BẬN GIỜ NÀY — bên bán xin đổi giờ, khách chọn lại (15/09/2026).

    khách đặt 10:00 ──► chủ nhà bận: "Đổi giờ" + đề xuất 14:00, 16:00
                        lịch → `doi_gio`, NHẢ khung 10:00
                    ──► khách chọn 14:00 (giờ đề xuất) → `approved` luôn
                        hoặc tự chọn 17:00 (giờ trống khác) → `pending`

Vì sao chọn giờ đề xuất thì DUYỆT LUÔN: chính bên bán vừa nói giờ đó được. Bắt
họ duyệt thêm lần nữa là thêm một vòng chờ cho một câu trả lời đã có.

Vì sao khung cũ bị LOẠI khỏi mọi lựa chọn: bên bán vừa nói bận đúng giờ đó —
cấu hình khung giờ của tin vẫn ghi "mở", nhưng người thật thì không rảnh.
"""

from __future__ import annotations

import json
from datetime import timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services import booking_slot_service as slots
from app.services.lich_xem_service import neo_cua

TRANG_THAI = "doi_gio"
#: Bên bán đề xuất tối đa bấy nhiêu giờ — nhiều hơn là đẩy việc chọn cho khách.
DE_XUAT_TOI_DA = 5
SO_NGAY_MAC_DINH = 7
#: Chỉ xin đổi được khi lịch còn đang chờ hoặc đã duyệt mà chưa diễn ra.
DOI_DUOC_TU = ("pending", "approved")


def _neo_slot(db: Session, b: models.ViewingAppointment):
    """Tin + phòng dùng để tra khung giờ, cùng cách tạo lịch đã dùng."""
    n = neo_cua(db, b)
    return n.house, (n.room.id if n.room is not None else None)


def de_xuat(b: models.ViewingAppointment) -> list[dict]:
    try:
        ds = json.loads(b.de_xuat_gio or "[]")
    except (TypeError, ValueError):
        return []
    return [x for x in ds if isinstance(x, dict) and x.get("ngay") and x.get("gio")]


def _khoa_cu(b: models.ViewingAppointment) -> Optional[tuple[str, str]]:
    if not b.gio_cu:
        return None
    phan = b.gio_cu.split(" ", 1)
    return (phan[0], phan[1]) if len(phan) == 2 else None


def gio_trong(
    db: Session, b: models.ViewingAppointment, so_ngay: int = SO_NGAY_MAC_DINH
) -> list[dict]:
    """Giờ còn đặt được trong [so_ngay] ngày tới, bỏ khung bên bán vừa báo bận.

    Trả [{"ngay", "gio": ["09:00-10:00", …]}], chỉ những ngày còn ít nhất một
    khung — ngày trống trơn thì không vẽ ra cho người ta bấm vào cho vui.
    """
    house, room_id = _neo_slot(db, b)
    bi_bo = {(b.booking_date, slots.normalize_slot(b.booking_time))}
    cu = _khoa_cu(b)
    if cu:
        bi_bo.add((cu[0], slots.normalize_slot(cu[1])))
    hom_nay = slots.vn_now().date()
    out = []
    for i in range(max(1, min(14, so_ngay))):
        ngay = (hom_nay + timedelta(days=i)).isoformat()
        kq = slots.available_slots(db, house, ngay, room_id=room_id)
        mo = [
            s["time"]
            for s in kq["slots"]
            if s["status"] == "open" and (ngay, s["time"]) not in bi_bo
        ]
        if mo:
            out.append({"ngay": ngay, "gio": mo})
    return out


def xin_doi_gio(
    db: Session,
    b: models.ViewingAppointment,
    uid: int,
    cac_gio: list[dict],
    ly_do: str,
) -> models.ViewingAppointment:
    if b.status not in DOI_DUOC_TU:
        raise HTTPException(409, "Lịch này không còn đổi giờ được")
    if len(cac_gio) > DE_XUAT_TOI_DA:
        raise HTTPException(422, f"Đề xuất tối đa {DE_XUAT_TOI_DA} giờ")
    house, room_id = _neo_slot(db, b)
    sach: list[dict] = []
    for x in cac_gio:
        ngay = str((x or {}).get("ngay") or "").strip()
        gio = slots.normalize_slot(str((x or {}).get("gio") or ""))
        if (ngay, gio) == (b.booking_date, slots.normalize_slot(b.booking_time)):
            raise HTTPException(422, "Không đề xuất lại đúng giờ đang bận")
        loi = slots.validate_booking(db, house, ngay, gio, room_id=room_id)
        if loi:
            raise HTTPException(
                409 if loi == "slot_taken" else 422,
                f"Giờ {gio[:5]} ngày {ngay} không đặt được nữa",
            )
        if {"ngay": ngay, "gio": gio} not in sach:
            sach.append({"ngay": ngay, "gio": gio})

    b.gio_cu = f"{b.booking_date} {slots.normalize_slot(b.booking_time)}"
    b.de_xuat_gio = json.dumps(sach, ensure_ascii=False)
    b.ly_do_doi = (ly_do or "").strip()[:500] or None
    b.nguoi_doi = uid
    # `doi_gio` KHÔNG thuộc ACTIVE_STATUSES → khung cũ được nhả cho người khác.
    b.status = TRANG_THAI
    return b


def khach_chon_gio(
    db: Session, b: models.ViewingAppointment, ngay: str, gio: str
) -> models.ViewingAppointment:
    if b.status != TRANG_THAI:
        raise HTTPException(409, "Lịch này không ở trạng thái chờ chọn giờ mới")
    gio = slots.normalize_slot(gio)
    cu = _khoa_cu(b)
    if cu and (ngay, gio) == (cu[0], slots.normalize_slot(cu[1])):
        raise HTTPException(422, "Bên bán đã báo bận giờ này, vui lòng chọn giờ khác")
    house, room_id = _neo_slot(db, b)
    loi = slots.validate_booking(db, house, ngay, gio, room_id=room_id)
    if loi:
        raise HTTPException(
            409 if loi == "slot_taken" else 422,
            "Giờ này vừa có người đặt, vui lòng chọn giờ khác"
            if loi == "slot_taken"
            else "Giờ này không đặt được nữa",
        )
    duoc_de_xuat = {"ngay": ngay, "gio": gio} in de_xuat(b)
    b.booking_date = ngay
    b.booking_time = gio
    b.status = "approved" if duoc_de_xuat else "pending"
    b.de_xuat_gio = None
    return b
