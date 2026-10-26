"""PHIẾU HẸN XEM NHÀ — dữ liệu cho màn đặt lịch và màn xác nhận (15/09/2026).

Hai màn khách thấy trước và sau khi đặt, đọc từ HAI hàm ở đây:

  * `thong_tin_dat`  — trước khi đặt: căn đang xem, sale sẽ đón, điểm đón.
  * `phieu`          — sau khi đặt: mã phiếu, giờ hẹn, sale kèm SĐT thật.

Vì sao SĐT sale chỉ lộ SAU khi đặt: trước khi đặt, trang này ai cũng mở được —
lộ số ở đây là thành danh bạ cho người cào dữ liệu (bất biến "SĐT masked"). Khách
đã có lịch hẹn thì phải gọi được người sẽ đón mình; giấu nữa là vô lý.

Sale do `lich_xem_service.Neo.sale_id` quyết định — cùng một nguồn với thông báo
và quyền duyệt lịch, để người khách thấy trên phiếu chính là người nhận yêu cầu.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app import models
from app.services import booking_slot_service as slots
from app.services import contact_privacy_service
from app.services import doi_gio_xem
from app.services.privacy.phone_mask import mask as _mask_phone_impl


def mask_phone(p: str) -> str:
    return _mask_phone_impl(p or "", region="vn")
from app.services.lich_xem_service import Neo, neo_cua

#: Hai hình thức xem. Nhãn nằm ở app; server chỉ giữ khoá.
HINH_THUC = ("truc_tiep", "video")
SO_NGUOI_TOI_DA = 10


def ma_phieu(appointment_id: int) -> str:
    """Mã phiếu đọc được qua điện thoại: LH-0042. Suy từ id, không lưu cột."""
    return f"LH-{appointment_id:04d}"


def _dia_chi(neo: Neo) -> str:
    h, b = neo.house, neo.building
    phan = (
        (h.address, h.district, h.city)
        if h is not None
        else ((b.address, b.district, b.city) if b is not None else ())
    )
    return ", ".join(x for x in phan if (x or "").strip())


def _toa_do(neo: Neo) -> tuple[Optional[float], Optional[float]]:
    h, b = neo.house, neo.building
    for o in (h, b):
        lat = getattr(o, "latitude", None) if o is not None else None
        lng = getattr(o, "longitude", None) if o is not None else None
        if lat is not None and lng is not None:
            return float(lat), float(lng)
    return None, None


def _tom_tat(neo: Neo) -> dict:
    h, r = neo.house, neo.room
    anh = list((h.images if h is not None else None) or (r.images if r is not None else None) or [])
    gia = float(h.price) if h is not None and h.price else (
        float(r.base_price) if r is not None and r.base_price else None
    )
    mua_ban = h is not None and getattr(h, "transaction_type", "rent") == "sale"
    return {
        "tieu_de": neo.ten,
        "anh": anh[0] if anh else None,
        # Cả bộ ảnh — màn chi tiết lịch xem của khách vuốt ảnh (1/N).
        "anh_ds": anh,
        "dien_tich": float(h.area) if h is not None and h.area else (
            float(r.area_m2) if r is not None and getattr(r, "area_m2", None) else None
        ),
        "dia_chi": _dia_chi(neo),
        "gia": gia,
        "don_vi": "" if mua_ban else "tháng",
        "house_id": h.id if h is not None else None,
        "room_id": r.id if r is not None else None,
    }


def _so_lan_xem_xong(db: Session, sale_id: int) -> int:
    """Số lịch xem ĐÃ XONG trên hàng sale này phụ trách — con số trên thẻ sale.

    Đếm theo ba đường sale gắn với hàng: tin sale đăng, phòng sale quản lý, toà
    sale phụ trách. Không đếm lịch 'pending' — "128 lượt xem" phải là lượt khách
    đã thật sự đi xem, không phải lượt bấm nút.
    """
    phong_cua_sale = (
        db.query(models.Room.id)
        .outerjoin(models.Building, models.Building.id == models.Room.building_id)
        .filter(
            or_(
                models.Room.managed_by_sale_id == sale_id,
                models.Building.sale_id == sale_id,
            )
        )
    )
    tin_cua_sale = db.query(models.House.id).filter(models.House.host_id == sale_id)
    return (
        db.query(models.ViewingAppointment)
        .filter(
            models.ViewingAppointment.status.in_(("completed", "locked")),
            or_(
                models.ViewingAppointment.room_id.in_(phong_cua_sale),
                models.ViewingAppointment.house_id.in_(tin_cua_sale),
            ),
        )
        .count()
    )


def _danh_gia_sale(db: Session, sale_id: int) -> Optional[float]:
    """Điểm TB các đánh giá trên tin sale đăng — "★ 4.9" trên thẻ sale.

    `None` khi chưa có đánh giá nào: app không vẽ sao, chứ không in "0.0".
    """
    tb = (
        db.query(func.avg(models.Review.rating))
        .join(models.House, models.House.id == models.Review.house_id)
        .filter(models.House.host_id == sale_id)
        .scalar()
    )
    return round(float(tb), 1) if tb else None


def _sale(db: Session, neo: Neo, lo_sdt: bool) -> Optional[dict]:
    sid = neo.sale_id
    u = db.get(models.User, sid) if sid else None
    if u is None:
        return None
    b = neo.building
    khu_vuc = ", ".join(
        x
        for x in ((b.district, b.city) if b is not None else (
            (neo.house.district, neo.house.city) if neo.house is not None else ()
        ))
        if (x or "").strip()
    )
    return {
        "id": u.id,
        "ten": u.name,
        "anh": u.avatar_path or None,
        "sdt": (u.phone or "") if lo_sdt else mask_phone(u.phone or ""),
        "so_lan_xem_xong": _so_lan_xem_xong(db, u.id),
        "danh_gia": _danh_gia_sale(db, u.id),
        "khu_vuc": khu_vuc,
    }


def _chu_nha(db: Session, neo: Neo, lo_sdt: bool) -> Optional[dict]:
    """CHỦ NHÀ THẬT của lịch hẹn — người mở cửa, không phải người đăng tin.

    Vì sao không dùng `houses.host_id`: tin do SALE đăng nên cột đó trỏ về
    sale. Màn "Làm việc với chủ nhà" của sale lấy theo cột ấy thì hiện chính
    sale kèm số của chính mình — sale gọi cho chính mình để xin lịch.

    SĐT chỉ lộ cho sale phụ trách và chính chủ nhà; khách xem phiếu vẫn thấy
    số masked (bất biến "SĐT masked", và khách liên hệ qua sale).
    """
    uid = neo.chu_nha_id
    u = db.get(models.User, uid) if uid else None
    if u is None:
        return None
    return {
        "id": u.id,
        "ten": u.name,
        "anh": u.avatar_path or None,
        "sdt": (u.phone or "") if lo_sdt else mask_phone(u.phone or ""),
    }


def thong_tin_dat(db: Session, neo: Neo) -> dict:
    lat, lng = _toa_do(neo)
    return {
        "tin": _tom_tat(neo),
        "sale": _sale(db, neo, lo_sdt=False),
        "diem_don": {"dia_chi": _dia_chi(neo), "lat": lat, "lng": lng},
        "hinh_thuc": list(HINH_THUC),
        "so_nguoi_toi_da": SO_NGUOI_TOI_DA,
    }


def duoc_xem_phieu(db: Session, b: models.ViewingAppointment, uid: int, la_admin: bool) -> bool:
    """Khách đã đặt, sale, chủ nhà, admin. Người ngoài: không."""
    if la_admin or uid == b.guest_id:
        return True
    n = neo_cua(db, b)
    ai = {n.sale_id, n.chu_nha_id}
    if n.building is not None:
        ai.add(n.building.host_id)
    if n.house is not None:
        ai.add(n.house.host_id)
    return uid in {x for x in ai if x is not None}


def phieu(
    db: Session,
    b: models.ViewingAppointment,
    nguoi_xem: Optional[int] = None,
) -> dict:
    neo = neo_cua(db, b)
    lat, lng = _toa_do(neo)
    khach = db.get(models.User, b.guest_id)
    ben_ban = {neo.sale_id, neo.chu_nha_id}
    if neo.building is not None:
        ben_ban.add(neo.building.host_id)
    # Sale/admin can coordinate both sides.  Customer and Owner never receive
    # the other's raw phone from a viewing slip until their mediated contract
    # is finalized; their own phone remains their own information.
    viewer_is_admin = False
    if nguoi_xem is not None:
        viewer = db.get(models.User, nguoi_xem)
        viewer_is_admin = bool(viewer and viewer.role == "admin")
    can_reveal_counterparty = contact_privacy_service.can_reveal_for_appointment(
        db,
        appointment_id=b.id,
        viewer_id=nguoi_xem,
        customer_id=b.guest_id,
        owner_id=neo.chu_nha_id,
        sale_id=neo.sale_id,
        is_admin=viewer_is_admin,
    )
    customer_phone_visible = bool(
        nguoi_xem == b.guest_id or can_reveal_counterparty or viewer_is_admin
    )
    owner_phone_visible = bool(
        nguoi_xem in ben_ban or can_reveal_counterparty or viewer_is_admin
    )
    return {
        "id": b.id,
        "ma": ma_phieu(b.id),
        "trang_thai": b.status,
        "ngay": b.booking_date,
        "gio": b.booking_time,
        "hinh_thuc": b.hinh_thuc or "truc_tiep",
        "so_nguoi": b.so_nguoi or 1,
        "ten_khach": b.ten_khach or (khach.name if khach else ""),
        "sdt_khach": (
            b.sdt_khach or (khach.phone if khach else "")
            if customer_phone_visible
            else mask_phone(b.sdt_khach or (khach.phone if khach else ""))
        ),
        "loi_nhan": b.message or "",
        "tin": _tom_tat(neo),
        # Khách ĐÃ có lịch hẹn → được gọi người sẽ đón mình.
        "sale": _sale(db, neo, lo_sdt=True),
        "chu_nha": _chu_nha(
            db, neo, lo_sdt=owner_phone_visible
        ),
        "diem_don": {"dia_chi": _dia_chi(neo), "lat": lat, "lng": lng},
        "doi_gio": _doi_gio(db, b, neo),
        "loai": b.loai,
        "ket_qua": ket_qua_xem(db, b.id),
    }


def ket_qua_nhieu(db: Session, appointment_ids: list[int]) -> dict[int, str]:
    """Kết quả khách tự ghi sau buổi xem: {id lịch: 'chot' | 'khong_chot'}.

    Hai nguồn, vì hai luồng ghi cùng chạy:
      * `viewing_results` (luồng v2) — INTERESTED / DECLINED; CONSIDERING là
        "đang cân nhắc" nên chưa tính là kết quả;
      * `rental_journeys` (luồng cũ) — có hành trình là đã chốt, trừ
        CUSTOMER_DECLINED. Huỷ hành trình về sau KHÔNG biến buổi xem thành
        "không chốt": lúc xem xong khách đã chốt thật.
    v2 ghi đè vì nó là nơi khách bấm gần nhất.
    """
    if not appointment_ids:
        return {}
    ra: dict[int, str] = {
        aid: ("khong_chot" if st == "CUSTOMER_DECLINED" else "chot")
        for aid, st in db.query(
            models.RentalJourney.appointment_id, models.RentalJourney.status
        ).filter(models.RentalJourney.appointment_id.in_(appointment_ids))
    }
    v2 = {"INTERESTED": "chot", "DECLINED": "khong_chot"}
    for aid, st in db.query(
        models.ViewingResult.appointment_id, models.ViewingResult.status
    ).filter(models.ViewingResult.appointment_id.in_(appointment_ids)):
        if st in v2:
            ra[aid] = v2[st]
    return ra


def ket_qua_xem(db: Session, appointment_id: int) -> Optional[str]:
    """'chot' · 'khong_chot' · None (chưa đánh giá) — xem `ket_qua_nhieu`."""
    return ket_qua_nhieu(db, [appointment_id]).get(appointment_id)


def _doi_gio(db: Session, b: models.ViewingAppointment, neo) -> Optional[dict]:
    """Bên bán đã xin đổi giờ chưa, đề xuất những giờ nào, giờ nào còn trống.

    Trả cả sau khi khách đã chọn (để phiếu còn nhắc "đổi từ 10:00") nhưng
    `de_xuat` chỉ có khi đang chờ khách chọn.
    """
    if not getattr(b, "gio_cu", None):
        return None
    dang_cho = b.status == doi_gio_xem.TRANG_THAI
    room_id = neo.room.id if neo.room is not None else None
    de_xuat = [
        {
            **x,
            "con_trong": slots.validate_booking(
                db, neo.house, x["ngay"], x["gio"], room_id=room_id
            ) is None,
        }
        for x in (doi_gio_xem.de_xuat(b) if dang_cho else [])
    ]
    nguoi = db.get(models.User, b.nguoi_doi) if b.nguoi_doi else None
    return {
        "dang_cho_chon": dang_cho,
        "gio_cu": b.gio_cu,
        "ly_do": b.ly_do_doi or "",
        "nguoi_doi": (nguoi.name if nguoi else "") or "",
        "la_sale": b.nguoi_doi is not None and b.nguoi_doi == neo.sale_id,
        "de_xuat": de_xuat,
    }
