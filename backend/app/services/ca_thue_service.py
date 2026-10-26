"""VÒNG ĐỜI MỘT CA THUÊ ngắn hạn: đặt → nhận phòng → đang ở → trả phòng.

Bốn màn của chủ nhà (chi tiết đặt phòng · check-in · đang ở · check-out) đều
hỏi cùng một thứ: **ca này đang ở bước nào, tiền đã tới đâu**. Gom vào một chỗ
để bốn màn không tự cộng tiền theo bốn cách.

Công thức tiền — viết MỘT lần ở đây:

    phải thu  = tiền phòng + Σ phụ thu
    đã thu    = cọc + Σ khoản 'thu' − Σ khoản 'hoàn'
    còn lại   = phải thu − đã thu      (>0 khách trả thêm · <0 hoàn lại khách)

Cọc nằm ở `reservations.deposit_paid` (dữ liệu cũ), các lần thu/hoàn nằm ở
`reservation_thanh_toan` — cộng cả hai nguồn CHỈ trong hàm `_tien`.

Quá giờ không tự trừ tiền: hệ ĐỀ XUẤT số phụ thu (số giờ lố × giá giờ) rồi để
người trực quyết. Tự ý cộng tiền vào hoá đơn của khách là cách nhanh nhất để
mất khách.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services import chiem_dung_service, loai_phong_service, reservation_service
from app.services import short_stay_service as stays
from app.services import so_phong
from app.services.sale_permissions import room_access_condition
from app.services.short_stay_service import local_now

#: Gia hạn tối đa một lần — quá mức này nên mở ca mới cho đúng sổ sách.
GIA_HAN_TOI_DA_GIO = 12

#: Quá chừng này phút mới coi là "ở lố" đáng thu tiền. Khách ra muộn 5 phút mà
#: đòi phụ thu là mất khách quen.
AN_HAN_QUA_GIO_PHUT = 15

#: Dọn phòng mặc định sau mỗi ca — đủ thay ga, lau nhanh. Khoá sinh TỰ ĐỘNG chứ
#: không bắt người trực bấm thêm một nút: phòng vừa trả mà nhận khách ngay là
#: giao phòng bẩn, và đó là lỗi không sửa lại được.
DON_PHONG_PHUT = 60


def _ca(db: Session, uid: int, res_id: int) -> tuple[models.Reservation, models.Room]:
    res = db.get(models.Reservation, res_id)
    if res is None or not res.booking_mode:
        raise HTTPException(404, "Không tìm thấy ca thuê")
    room = (
        db.query(models.Room)
        .outerjoin(models.Building, models.Building.id == models.Room.building_id)
        .filter(models.Room.id == res.room_id, room_access_condition(uid))
        .first()
    )
    if room is None:
        raise HTTPException(404, "Không tìm thấy ca thuê")
    return res, room


def _gac_tien(db: Session, uid: int, room: models.Room, la_admin: bool) -> None:
    """Tiền của ca là tiền của chủ phòng — sale phụ trách xem lịch, không thu."""
    toa = db.get(models.Building, room.building_id)
    if not so_phong.duoc_xem_tai_chinh(
        room, toa.host_id if toa else None, uid, la_admin
    ):
        raise HTTPException(403, "Chỉ chủ phòng mới ghi được tiền của ca thuê")


def _khoang(res: models.Reservation) -> tuple[datetime, datetime]:
    vao = res.check_in_at or datetime.fromisoformat(f"{res.check_in_date}T00:00")
    ra = res.check_out_at or datetime.fromisoformat(f"{res.check_out_date}T00:00")
    return vao, ra


def _phu_thu(db: Session, res_id: int) -> list[models.ReservationPhuThu]:
    return (
        db.query(models.ReservationPhuThu)
        .filter(models.ReservationPhuThu.reservation_id == res_id)
        .order_by(models.ReservationPhuThu.id)
        .all()
    )


def _thanh_toan(db: Session, res_id: int) -> list[models.ReservationThanhToan]:
    return (
        db.query(models.ReservationThanhToan)
        .filter(models.ReservationThanhToan.reservation_id == res_id)
        .order_by(models.ReservationThanhToan.id)
        .all()
    )


def _tien(res: models.Reservation, phu_thu: list, thanh_toan: list) -> dict:
    tien_phong = float(res.total_amount or 0)
    tong_phu_thu = sum(float(x.thanh_tien or 0) for x in phu_thu)
    coc = float(res.deposit_paid or 0)
    thu = sum(float(x.so_tien or 0) for x in thanh_toan if x.loai == models.ReservationThanhToan.THU)
    hoan = sum(float(x.so_tien or 0) for x in thanh_toan if x.loai == models.ReservationThanhToan.HOAN)
    phai_thu = tien_phong + tong_phu_thu
    da_thu = coc + thu - hoan
    con_lai = round(phai_thu - da_thu)
    return {
        "tien_phong": tien_phong,
        "phu_thu": tong_phu_thu,
        "phai_thu": phai_thu,
        "coc": coc,
        "da_thu": da_thu,
        # >0 = khách phải trả thêm · <0 = hoàn lại khách. Một con số, hai chiều,
        # để màn không phải tự suy dấu.
        "con_lai": con_lai,
        "hoan_lai": -con_lai if con_lai < 0 else 0.0,
    }


def _gia_gio(db: Session, room: models.Room) -> Optional[float]:
    k = (
        db.query(models.RoomKenh)
        .filter(
            models.RoomKenh.room_id == room.id,
            models.RoomKenh.kenh == models.RoomKenh.NGAN_HAN,
        )
        .first()
    )
    loai = loai_phong_service.loai_cua_phong(db, room)
    return loai_phong_service.gia_hieu_luc(k, loai)["gia_theo_gio"]


def _de_xuat_qua_gio(
    db: Session, res: models.Reservation, room: models.Room, now: datetime
) -> Optional[dict]:
    """Khách ở lố thì đề xuất phụ thu — KHÔNG tự cộng vào hoá đơn."""
    if res.status != "checked_in":
        return None
    _vao, ra = _khoang(res)
    tre = int((now - ra).total_seconds() // 60)
    if tre <= AN_HAN_QUA_GIO_PHUT:
        return None
    gia = _gia_gio(db, room)
    so_gio = (tre + 59) // 60
    return {
        "phut": tre,
        "so_gio": so_gio,
        "don_gia": gia,
        "de_xuat": round(gia * so_gio) if gia else None,
        "ten": f"Phụ thu quá giờ ({so_gio} giờ)",
    }


def chi_tiet(
    db: Session, uid: int, res_id: int, *, la_admin: bool = False
) -> dict:
    """Mọi thứ của một ca thuê trong MỘT lượt gọi — dùng cho cả bốn màn."""
    res, room = _ca(db, uid, res_id)
    toa = db.get(models.Building, room.building_id)
    xem_tien = so_phong.duoc_xem_tai_chinh(
        room, toa.host_id if toa else None, uid, la_admin
    )
    now = local_now()
    vao, ra = _khoang(res)
    phu_thu = _phu_thu(db, res.id)
    thanh_toan = _thanh_toan(db, res.id)
    loai = loai_phong_service.loai_cua_phong(db, room)

    tong_phut = max(1, int((ra - vao).total_seconds() // 60))
    da = max(0, min(tong_phut, int((now - vao).total_seconds() // 60)))
    ra_dict = {
        "id": res.id,
        "ma_dat": res.booking_code or "",
        "trang_thai": res.status,
        "kieu": res.booking_mode or "",
        "nhan_kieu": stays.MODES.get(res.booking_mode or "", ("Theo ngày",))[0],
        "nguon": res.source,
        "vao": vao.isoformat(timespec="minutes"),
        "ra": ra.isoformat(timespec="minutes"),
        "bay_gio": now.isoformat(timespec="minutes"),
        "ghi_chu": res.note,
        "tien_do": {
            "tong_phut": tong_phut,
            "da_o_phut": da,
            "con_phut": max(0, tong_phut - da),
            "phan_tram": round(da / tong_phut * 100, 1),
            "qua_gio": now > ra and res.status == "checked_in",
            # Trước giờ nhận thì đếm ngược — màn "sắp đón khách" cần con số này.
            "con_toi_gio_vao": max(0, int((vao - now).total_seconds() // 60)),
        },
        "phong": {
            "id": room.id,
            "ma": room.code,
            "tang": room.tang,
            "suc_chua": room.capacity,
            "anh": list(room.images or []),
            "hang": loai.ten if loai is not None else None,
            "giuong": loai.giuong if loai is not None else None,
        },
        "toa": {
            "id": room.building_id,
            "ten": toa.name if toa else "",
            "dia_chi": (toa.address or "") if toa else "",
        },
        "xem_tai_chinh": xem_tien,
        # Sale dẫn khách về (ảnh chụp lúc đặt). Rỗng với ca vãng lai tại quầy.
        "sale": (
            {"id": res.sale_id, "ten": sale.name}
            if (sale := (db.get(models.User, res.sale_id) if res.sale_id else None))
            else None
        ),
        "tu_tin": res.house_id,
        "de_xuat_qua_gio": _de_xuat_qua_gio(db, res, room, now),
        "gia_gio": _gia_gio(db, room),
    }
    if xem_tien:
        ra_dict |= {
            "khach": {
                "ten": res.guest_name,
                "sdt": res.guest_phone or "",
                "email": res.guest_email,
            },
            "tien": _tien(res, phu_thu, thanh_toan),
            "phu_thu": [
                {
                    "id": x.id,
                    "loai": x.loai,
                    "ten": x.ten,
                    "don_gia": float(x.don_gia or 0),
                    "so_luong": float(x.so_luong or 0),
                    "thanh_tien": float(x.thanh_tien or 0),
                    "ghi_chu": x.ghi_chu,
                }
                for x in phu_thu
            ],
            "thanh_toan": [
                {
                    "id": x.id,
                    "loai": x.loai,
                    "so_tien": float(x.so_tien or 0),
                    "hinh_thuc": x.hinh_thuc,
                    "ghi_chu": x.ghi_chu,
                    "luc": x.created_at.isoformat(timespec="minutes")
                    if x.created_at
                    else None,
                }
                for x in thanh_toan
            ],
        }
    return ra_dict


def them_phu_thu(
    db: Session,
    uid: int,
    res_id: int,
    *,
    ten: str,
    don_gia: float,
    so_luong: float = 1,
    loai: str = models.ReservationPhuThu.DICH_VU,
    ghi_chu: Optional[str] = None,
    la_admin: bool = False,
) -> models.ReservationPhuThu:
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    if res.status in ("cancelled", "rejected"):
        raise HTTPException(409, "Ca thuê đã huỷ — không ghi thêm phụ thu")
    if not (ten or "").strip():
        raise HTTPException(422, "Phụ thu phải có tên để khách đọc hiểu")
    if don_gia < 0 or so_luong <= 0:
        raise HTTPException(422, "Đơn giá và số lượng không hợp lệ")
    x = models.ReservationPhuThu(
        reservation_id=res.id,
        loai=loai,
        ten=ten.strip(),
        don_gia=don_gia,
        so_luong=so_luong,
        thanh_tien=round(don_gia * so_luong),
        ghi_chu=(ghi_chu or "").strip() or None,
        nguoi_ghi=uid,
    )
    db.add(x)
    db.flush()
    return x


def xoa_phu_thu(
    db: Session, uid: int, res_id: int, phu_thu_id: int, *, la_admin: bool = False
) -> None:
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    x = db.get(models.ReservationPhuThu, phu_thu_id)
    if x is None or x.reservation_id != res.id:
        raise HTTPException(404, "Không tìm thấy khoản phụ thu")
    db.delete(x)
    db.flush()


def ghi_thanh_toan(
    db: Session,
    uid: int,
    res_id: int,
    *,
    so_tien: float,
    loai: str = models.ReservationThanhToan.THU,
    hinh_thuc: str = models.ReservationThanhToan.TIEN_MAT,
    ghi_chu: Optional[str] = None,
    la_admin: bool = False,
) -> models.ReservationThanhToan:
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    if so_tien <= 0:
        raise HTTPException(422, "Số tiền phải lớn hơn 0")
    if loai not in (models.ReservationThanhToan.THU, models.ReservationThanhToan.HOAN):
        raise HTTPException(422, "Loại giao dịch không hợp lệ")
    x = models.ReservationThanhToan(
        reservation_id=res.id,
        loai=loai,
        so_tien=so_tien,
        hinh_thuc=hinh_thuc,
        ghi_chu=(ghi_chu or "").strip() or None,
        nguoi_ghi=uid,
    )
    db.add(x)
    db.flush()
    return x


def gia_han(
    db: Session,
    uid: int,
    res_id: int,
    *,
    them_phut: int,
    tinh_tien: bool = True,
    la_admin: bool = False,
) -> models.Reservation:
    """Kéo dài ca đang ở. Kiểm TRÙNG LỊCH trước, rồi mới cộng giờ và tiền.

    Không kiểm trùng thì gia hạn sẽ đè lên ca đã nhận của khách sau — lỗi đắt
    nhất của mô hình này, vì lúc đó đã có hai người cầm chìa khoá cùng phòng.
    """
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    if res.status not in ("approved", "checked_in"):
        raise HTTPException(409, "Chỉ gia hạn được ca đang hiệu lực")
    if not 15 <= them_phut <= GIA_HAN_TOI_DA_GIO * 60:
        raise HTTPException(422, f"Gia hạn từ 15 phút đến {GIA_HAN_TOI_DA_GIO} giờ")

    vao, ra = _khoang(res)
    moi = ra + timedelta(minutes=them_phut)
    # Bỏ chỗ cũ ra khỏi lịch rồi hỏi lại, nếu không chính ca này chặn chính nó.
    chiem_dung_service.go(db, "reservation", res.id)
    if stays.busy(db, room.id, ra, moi):
        chiem_dung_service.ghi(
            db, room_id=room.id, tu_ngay=vao.date(),
            den_ngay=ra.date() + timedelta(days=1), tu_luc=vao, den_luc=ra,
            kenh="ngan_han", nguon="reservation", nguon_id=res.id,
        )
        raise HTTPException(409, "Khoảng gia hạn đã có lịch khác — đổi phòng cho khách sau")

    res.check_out_at = moi
    res.check_out_date = moi.date().isoformat()
    from app.services import lich_su_dat  # noqa: PLC0415

    lich_su_dat.ghi(
        db, lich_su_dat.DON, res.id, "gia_han", uid,
        {"tra": stays.iso(ra)},
        {"hinh_thuc": res.booking_mode, "nhan": stays.iso(vao), "tra": stays.iso(moi)},
    )
    chiem_dung_service.ghi(
        db, room_id=room.id, tu_ngay=vao.date(),
        den_ngay=moi.date() + timedelta(days=1), tu_luc=vao, den_luc=moi,
        kenh="ngan_han", nguon="reservation", nguon_id=res.id,
    )
    if tinh_tien:
        gia = _gia_gio(db, room)
        if gia:
            so_gio = (them_phut + 59) // 60
            them_phu_thu(
                db, uid, res.id,
                ten=f"Gia hạn {so_gio} giờ",
                don_gia=gia, so_luong=so_gio,
                loai=models.ReservationPhuThu.QUA_GIO,
                la_admin=la_admin,
            )
    db.flush()
    return res


def nhan_phong(
    db: Session,
    uid: int,
    res_id: int,
    *,
    thu: float = 0,
    hinh_thuc: str = models.ReservationThanhToan.TIEN_MAT,
    ghi_chu: Optional[str] = None,
    la_admin: bool = False,
) -> models.Reservation:
    """Thủ tục nhận phòng: ghi tiền thu tại quầy (nếu có) rồi check-in."""
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    if thu > 0:
        ghi_thanh_toan(
            db, uid, res.id, so_tien=thu, hinh_thuc=hinh_thuc,
            ghi_chu="Thu khi nhận phòng", la_admin=la_admin,
        )
    if ghi_chu:
        res.note = f"{(res.note or '').strip()}\n{ghi_chu.strip()}".strip()
    if res.status == "pending":
        reservation_service.approve(db, res.host_id, res.id, actor_id=uid)
    reservation_service.check_in(db, res.host_id, res.id, actor_id=uid)
    db.flush()
    return res


def khoa_don_phong(
    db: Session, room_id: int, phut_don: int = DON_PHONG_PHUT
) -> Optional[int]:
    """Khoá phòng ``phut_don`` phút để dọn, tính từ bây giờ; trả id khoá.

    Dùng chung cho MỌI đường trả phòng (quầy lễ tân lẫn nút trả phòng của
    sale ở ``/actions``) — sót ở một đường là ca sau nhận phòng chưa dọn.
    Khoảng đó đã có lịch (khách kế tiếp vào sát giờ) thì không khoá đè.
    """
    if phut_don <= 0:
        return None
    now = local_now().replace(second=0, microsecond=0)
    den = now + timedelta(minutes=phut_don)
    if stays.busy(db, room_id, now, den):
        return None
    dong = chiem_dung_service.ghi(
        db, room_id=room_id, tu_ngay=now.date(),
        den_ngay=den.date() + timedelta(days=1), tu_luc=now, den_luc=den,
        kenh="khoa", nguon="thu_cong", ghi_chu="Dọn phòng sau trả phòng",
    )
    return dong.id


def tra_phong(
    db: Session,
    uid: int,
    res_id: int,
    *,
    thu_them: float = 0,
    hoan_lai: float = 0,
    hinh_thuc: str = models.ReservationThanhToan.TIEN_MAT,
    phut_don: int = DON_PHONG_PHUT,
    kiem_phong: Optional[str] = None,
    ghi_chu: Optional[str] = None,
    la_admin: bool = False,
) -> dict:
    """Trả phòng & quyết toán: ghi tiền, check-out, và khoá phòng để dọn.

    Khoá dọn phòng sinh ngay tại đây vì đó là việc BẮT BUỘC sau mỗi ca — để
    người trực tự nhớ tạo là sẽ có ca sau nhận vào phòng chưa dọn.
    """
    res, room = _ca(db, uid, res_id)
    _gac_tien(db, uid, room, la_admin)
    if res.status != "checked_in":
        raise HTTPException(409, "Chỉ trả phòng được khi khách đã nhận phòng")

    if thu_them > 0:
        ghi_thanh_toan(
            db, uid, res.id, so_tien=thu_them, hinh_thuc=hinh_thuc,
            ghi_chu="Thu khi trả phòng", la_admin=la_admin,
        )
    if hoan_lai > 0:
        ghi_thanh_toan(
            db, uid, res.id, so_tien=hoan_lai,
            loai=models.ReservationThanhToan.HOAN, hinh_thuc=hinh_thuc,
            ghi_chu="Hoàn cọc khi trả phòng", la_admin=la_admin,
        )
    if kiem_phong is not None:
        res.ghi_chu_kiem_phong = kiem_phong.strip() or None
    if ghi_chu:
        res.note = f"{(res.note or '').strip()}\n{ghi_chu.strip()}".strip()

    reservation_service.check_out(db, res.host_id, res.id, actor_id=uid)

    chan_id = khoa_don_phong(db, room.id, phut_don)
    db.flush()
    return {
        "reservation_id": res.id,
        "trang_thai": res.status,
        "chan_don_id": chan_id,
        "don_den": (
            local_now().replace(second=0, microsecond=0) + timedelta(minutes=phut_don)
        ).isoformat() if chan_id else None,
        "tien": _tien(res, _phu_thu(db, res.id), _thanh_toan(db, res.id)),
    }
