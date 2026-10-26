"""PHIẾU ĐẶT PHÒNG NGẮN HẠN — dữ liệu cho màn đặt phòng và màn xác nhận (16/09/2026).

Cùng khuôn với lịch xem nhà dài hạn (`phieu_hen_xem.py`), khác ở chỗ cốt lõi:
ngắn hạn KHÔNG hẹn đi xem — khách ĐẶT LUÔN. Ba hàm khách thấy:

  * `thong_tin_dat` — trước khi đặt: phòng, ba gói giá, sale phụ trách, địa chỉ.
  * `lich_ban`      — các khoảng phòng đã có người, để app gạch giờ không đặt được
                      thay vì cho khách chọn xong rồi mới báo "phòng vừa có lịch".
  * `phieu`         — sau khi đặt: mã, giờ nhận/trả, tiền, hạn huỷ, sale kèm SĐT thật.

Liên hệ đi qua SALE, không qua chủ nhà (luật 14/09/2026). Sale là
`sale_phu_trach.sale_cua_phong` — cùng nguồn với cổng đặt phòng và thông báo.
SĐT sale bị che trước khi đặt (trang công khai), lộ trên phiếu cho đúng khách.
"""

from __future__ import annotations

import json
from datetime import date, datetime, time, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.services import chiem_dung_service, sale_phu_trach
from app.services import short_stay_service as stays
from app.services.privacy.phone_mask import mask as _mask_phone_impl


def mask_phone(p: str) -> str:
    return _mask_phone_impl(p or "", region="vn")

#: Xa nhất app được hỏi lịch bận một lượt — dải ngày trên màn đặt là 14 ngày.
SO_NGAY_TOI_DA = 31

CHINH_SACH = (
    "Thanh toán tại nơi lưu trú khi nhận phòng — ứng dụng chưa thu tiền.",
    "Mang CCCD/hộ chiếu của người nhận phòng.",
    "Qua đêm và theo ngày trả phòng trước 12:00 trưa.",
)


def _tin(db: Session, room: models.Room, house_id: Optional[int]) -> Optional[models.House]:
    h = db.get(models.House, house_id) if house_id else None
    if h is not None and h.source_room_id != room.id:
        h = None
    if h is None and room.marketplace_house_id:
        h = db.get(models.House, room.marketplace_house_id)
    return h


def _dia_chi(toa: Optional[models.Building]) -> str:
    if toa is None:
        return ""
    return ", ".join(x for x in (toa.address, toa.district, toa.city) if (x or "").strip())


def _phong(db: Session, room: models.Room, h: Optional[models.House]) -> dict:
    toa = db.get(models.Building, room.building_id)
    k = stays.channel(db, room.id, enabled=False)
    hang = (k.loai_phong if k is not None else None) or "Phòng"
    anh = list((h.images if h is not None else None) or room.images or [])
    return {
        "room_id": room.id,
        "ma": room.code,
        "hang": hang,
        "toa": toa.name if toa is not None else "",
        "anh": anh[0] if anh else None,
        "dien_tich": float(room.area_m2) if room.area_m2 else None,
        "suc_chua": room.capacity or None,
        "dia_chi": _dia_chi(toa),
        "house_id": h.id if h is not None else None,
    }


def _diem_den(db: Session, room: models.Room, h: Optional[models.House]) -> dict:
    lat = getattr(h, "latitude", None) if h is not None else None
    lng = getattr(h, "longitude", None) if h is not None else None
    return {
        "dia_chi": _dia_chi(db.get(models.Building, room.building_id)),
        "lat": float(lat) if lat is not None and lng is not None else None,
        "lng": float(lng) if lat is not None and lng is not None else None,
    }


def _so_don_xong(db: Session, sale_id: int) -> int:
    """Số lượt khách đã ở xong qua sale này — "đã trả phòng", không đếm đơn chờ."""
    return (
        db.query(models.Reservation)
        .filter(
            models.Reservation.sale_id == sale_id,
            models.Reservation.status == "checked_out",
        )
        .count()
    )


def _sale(db: Session, room: models.Room, lo_sdt: bool, sale_id: Optional[int] = None) -> Optional[dict]:
    sid = sale_id or sale_phu_trach.sale_cua_phong(db, room)
    # Sale trùng chủ phòng = đặt thẳng với chủ nhà → coi như không có sale.
    if not sid or (sale_id is None and sid == sale_phu_trach.chu_cua_phong(db, room)):
        return None
    u = db.get(models.User, sid)
    if u is None:
        return None
    toa = db.get(models.Building, room.building_id)
    return {
        "id": u.id,
        "ten": u.name,
        "anh": u.avatar_path or None,
        "sdt": (u.phone or "") if lo_sdt else mask_phone(u.phone or ""),
        "so_don_xong": _so_don_xong(db, u.id),
        "khu_vuc": ", ".join(
            x for x in ((toa.district, toa.city) if toa is not None else ()) if (x or "").strip()
        ),
    }


def thong_tin_dat(db: Session, room: models.Room, house_id: Optional[int] = None) -> dict:
    h = _tin(db, room, house_id)
    goi = stays.products(stays.channel(db, room.id))
    sale = _sale(db, room, lo_sdt=False)
    return {
        "phong": _phong(db, room, h),
        "goi": goi,
        "sale": sale,
        # Không có sale thì server từ chối đặt — app nói trước, không để khách
        # điền xong mới biết.
        "nhan_dat": bool(goi) and sale is not None,
        "diem_den": _diem_den(db, room, h),
        "gio_tra": stays.GIO_TRA_TRUA,
        "chinh_sach": list(CHINH_SACH),
    }


def lich_ban(db: Session, room_id: int, tu: date, so_ngay: int) -> list[dict]:
    """Các khoảng [tu, den) phòng đã bận — chỉ thời gian, KHÔNG có ai đặt.

    Gom đúng ba nguồn mà `short_stay_service.busy` dùng để từ chối đặt: sổ chiếm
    dụng chung, đơn cũ chưa ghi sổ, và ngày chủ nhà khoá tay. Lệch một nguồn là
    app cho chọn một giờ mà server sẽ báo bận.
    """
    so_ngay = max(1, min(SO_NGAY_TOI_DA, so_ngay))
    dau = datetime.combine(tu, time())
    cuoi = dau + timedelta(days=so_ngay)
    khoang: list[tuple[datetime, datetime]] = []
    for row in chiem_dung_service.lich(db, room_id, tu, cuoi.date()):
        khoang.append((
            row.tu_luc or datetime.combine(row.tu_ngay, time()),
            row.den_luc or datetime.combine(row.den_ngay, time()),
        ))
    for r in db.query(models.Reservation).filter(
        models.Reservation.room_id == room_id,
        models.Reservation.status.in_(("pending", "approved", "checked_in")),
    ):
        a = r.check_in_at or datetime.combine(date.fromisoformat(str(r.check_in_date)), time())
        b = r.check_out_at or datetime.combine(date.fromisoformat(str(r.check_out_date)), time())
        khoang.append((a, b))
    for d in db.query(models.Availability.date).filter(
        models.Availability.room_id == room_id,
        models.Availability.status == "blocked",
        models.Availability.date >= tu.isoformat(),
        models.Availability.date < cuoi.date().isoformat(),
    ):
        ngay = datetime.combine(date.fromisoformat(str(d[0])), time())
        khoang.append((ngay, ngay + timedelta(days=1)))

    gop: list[list[datetime]] = []
    for a, b in sorted((a, b) for a, b in khoang if a < cuoi and b > dau and a < b):
        if gop and a <= gop[-1][1]:
            gop[-1][1] = max(gop[-1][1], b)
        else:
            gop.append([a, b])
    return [{"tu": stays.iso(a), "den": stays.iso(b)} for a, b in gop]


def duoc_xem(db: Session, res: models.Reservation, uid: int, la_admin: bool) -> bool:
    """Khách của đơn, sale của đơn, chủ phòng, admin. Người ngoài: không."""
    if la_admin:
        return True
    room = db.get(models.Room, res.room_id)
    ai = {res.guest_user_id, res.sale_id, res.host_id}
    if room is not None:
        ai.add(sale_phu_trach.chu_cua_phong(db, room))
    return uid in {x for x in ai if x is not None}


def phieu(db: Session, res: models.Reservation) -> dict:
    room = db.get(models.Room, res.room_id)
    h = _tin(db, room, res.house_id)
    gia = json.loads(res.price_snapshot or "{}")
    return {
        "id": res.id,
        "ma": res.booking_code or f"DP-{res.id:04d}",
        "trang_thai": res.status,
        "nhan_trang_thai": stays.STATUSES.get(res.status, res.status),
        "hinh_thuc": res.booking_mode,
        "nhan_luc": stays.iso(res.check_in_at),
        "tra_luc": stays.iso(res.check_out_at),
        "so_luong": gia.get("quantity"),
        "don_vi": gia.get("unit"),
        "don_gia": gia.get("unit_price"),
        "tong": res.total_amount,
        "huy_mien_phi_den": gia.get("free_cancel_until"),
        "huy_duoc": stays.cancellation(res),
        "so_khach": getattr(res, "so_khach", None),
        "ten_khach": res.guest_name,
        "sdt_khach": res.guest_phone,
        "ghi_chu": res.note or "",
        "ly_do_tu_choi": res.rejection_reason or "",
        "phong": _phong(db, room, h),
        # Khách ĐÃ đặt → gọi được người phụ trách phòng mình.
        "sale": _sale(db, room, lo_sdt=True, sale_id=res.sale_id),
        "diem_den": _diem_den(db, room, h),
        "chinh_sach": list(CHINH_SACH),
    }
