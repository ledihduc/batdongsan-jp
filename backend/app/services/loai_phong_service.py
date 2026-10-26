"""HẠNG PHÒNG — quản lý phòng ngắn hạn theo NHÓM, không theo từng phòng.

Khách chọn "Studio VIP", không chọn "phòng 201". Lễ tân mới là người gán số
phòng lúc nhận. Nên câu hỏi điều hành của mô hình này là **"hạng này còn mấy
phòng trống"**, chứ không phải "phòng 201 thế nào" — màn quản lý phải trả lời
được câu đó trước.

Ở đây gom: danh sách hạng của toà kèm thống kê (tổng · đang có khách · bảo trì
· trống), tạo/sửa/xoá hạng, và gán phòng vào hạng.

"Đang có khách" dùng CHUNG luật với Sổ phòng (`so_phong.khach_dang_o`) — hai
nơi tự đếm là một ngày nào đó hai màn nói hai con số.
"""

from __future__ import annotations

from datetime import datetime, time, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services import chiem_dung_service, so_phong
from app.services.sale_permissions import room_access_condition
from app.services.short_stay_service import local_now, local_time

#: Tên hạng dài hơn chừng này là người dùng đang nhét mô tả vào ô tên.
DAI_TOI_DA = 120

#: Ba ô giá của lưu trú ngắn hạn, đúng tên cột ở CẢ `room_kenh` và `loai_phong`
#: — nhờ trùng tên mà chỗ nào cũng lặp được một vòng, không viết tay ba lần.
CAC_GIA = ("gia_theo_gio", "gia_qua_dem", "gia_theo_ngay")


def loai_cua_phong(db: Session, room: models.Room) -> Optional[models.LoaiPhong]:
    """Hạng của phòng, `None` nếu chưa xếp hạng (phòng thuê tháng luôn `None`)."""
    ma = getattr(room, "loai_phong_id", None)
    return db.get(models.LoaiPhong, ma) if ma else None


def gia_hieu_luc(
    kenh: Optional[models.RoomKenh], loai: Optional[models.LoaiPhong]
) -> dict[str, Optional[float]]:
    """Giá đang áp cho phòng: ô RIÊNG của phòng → giá của HẠNG → `None`.

    `None` phải khác `0`: `0` là miễn phí, `None` là "chưa khai, đừng bán hình
    thức này". Gộp hai thứ làm một là bán một đêm 0đ vì quên điền giá.

    Thứ tự này chỉ được viết ở ĐÂY. Viết lại ở từng nơi đọc là cách sinh ra hai
    câu trả lời khác nhau cho cùng một câu hỏi.
    """
    ra: dict[str, Optional[float]] = {}
    for ten in CAC_GIA:
        rieng = getattr(kenh, ten, None) if kenh is not None else None
        chung = getattr(loai, ten, None) if loai is not None else None
        ra[ten] = rieng if rieng is not None else chung
    return ra


def ap_gia_hang_vao_phong(db: Session, hang: models.LoaiPhong) -> int:
    """Đẩy giá của hạng xuống các phòng CHƯA có giá riêng.

    `short_stay_service.quote` — chỗ duy nhất tính tiền — chỉ đọc `room_kenh`,
    và tìm kiếm ngắn hạn cũng lọc theo đó. Hạng có giá mà phòng để trống thì
    phòng không lên chợ và không đặt được. Chỉ điền vào ô đang TRỐNG: phòng góc
    khai giá riêng thì giữ nguyên — đó là lý do ô riêng tồn tại.
    """
    ds = db.query(models.Room).filter(models.Room.loai_phong_id == hang.id).all()
    sua = 0
    for phong in ds:
        k = (
            db.query(models.RoomKenh)
            .filter(
                models.RoomKenh.room_id == phong.id,
                models.RoomKenh.kenh == models.RoomKenh.NGAN_HAN,
            )
            .first()
        )
        if k is None:
            continue
        doi = False
        for ten in CAC_GIA:
            if getattr(k, ten, None) is None and getattr(hang, ten, None) is not None:
                setattr(k, ten, getattr(hang, ten))
                doi = True
        # `room_kenh.gia` là giá NIÊM YẾT của kênh (đơn vị 'dem'): giữ đồng bộ
        # với giá qua đêm, không thì sổ phòng in một số mà đặt phòng tính số khác.
        if not k.gia and hang.gia_qua_dem:
            k.gia = hang.gia_qua_dem
            doi = True
        if doi:
            sua += 1
    if sua:
        db.flush()
    return sua


def _toa(db: Session, uid: int, building_id: int) -> models.Building:
    toa = (
        db.query(models.Building)
        .outerjoin(models.Room, models.Room.building_id == models.Building.id)
        .filter(models.Building.id == building_id, room_access_condition(uid))
        .first()
    )
    if toa is None:
        raise HTTPException(404, "Toà nhà không tồn tại hoặc không thuộc bạn")
    return toa


def _hang_cua_toi(db: Session, uid: int, loai_id: int) -> models.LoaiPhong:
    hang = db.get(models.LoaiPhong, loai_id)
    if hang is None:
        raise HTTPException(404, "Hạng phòng không tồn tại")
    _toa(db, uid, hang.building_id)
    return hang


def _ten_sach(ten: str) -> str:
    ten = (ten or "").strip()
    if not ten:
        raise HTTPException(422, "Hạng phòng phải có tên")
    if len(ten) > DAI_TOI_DA:
        raise HTTPException(422, f"Tên hạng dài quá {DAI_TOI_DA} ký tự")
    return ten


def _trung_ten(db: Session, building_id: int, ten: str, tru: Optional[int] = None) -> bool:
    q = db.query(models.LoaiPhong.id).filter(
        models.LoaiPhong.building_id == building_id,
        models.LoaiPhong.ten == ten,
    )
    if tru is not None:
        q = q.filter(models.LoaiPhong.id != tru)
    return q.first() is not None


def _hang_ra(
    hang: models.LoaiPhong,
    phong: list[models.Room],
    dang_o: set[int],
    gia: dict[str, Optional[float]],
) -> dict:
    bao_tri = sum(1 for p in phong if p.status == "maintenance")
    co_khach = sum(1 for p in phong if p.id in dang_o)
    return {
        "id": hang.id,
        "ten": hang.ten,
        "mo_ta": hang.mo_ta,
        "suc_chua": hang.suc_chua,
        "dien_tich": hang.dien_tich,
        "giuong": hang.giuong,
        "anh": list(hang.anh or []),
        "tien_nghi": list(hang.tien_nghi or []),
        "gia_theo_gio": hang.gia_theo_gio,
        "gia_qua_dem": hang.gia_qua_dem,
        "gia_theo_ngay": hang.gia_theo_ngay,
        # Giá HIỆU LỰC của hạng: nếu hạng chưa khai thì lấy của phòng đầu tiên
        # đã khai — để màn không hiện "chưa có giá" trong khi chợ đang bán.
        "gia_hieu_luc": gia,
        "thu_tu": hang.thu_tu,
        "dang_ban": bool(hang.dang_ban),
        "so_phong": len(phong),
        "dang_co_khach": co_khach,
        "bao_tri": bao_tri,
        "trong": max(0, len(phong) - co_khach - bao_tri),
        "phong": [
            {
                "id": p.id,
                "ma": p.code,
                "trang_thai": p.status,
                "co_khach": p.id in dang_o,
            }
            for p in phong
        ],
    }


def danh_sach(
    db: Session, uid: int, building_id: int, *, now: Optional[datetime] = None
) -> dict:
    """Hạng của toà + thống kê phòng, kèm những phòng CHƯA xếp hạng."""
    _toa(db, uid, building_id)
    now = now or local_now()
    phong = (
        db.query(models.Room)
        .filter(models.Room.building_id == building_id)
        .order_by(models.Room.code)
        .all()
    )
    dang_o = set(so_phong.khach_dang_o(db, [p.id for p in phong], now).keys())
    hop_dong = set(so_phong.hop_dong_hieu_luc(db, [p.id for p in phong]).keys())
    # Phòng thuê tháng cũng là "đang có khách" — toà hỗn hợp vẫn đếm đúng.
    dang_o |= hop_dong

    ds = (
        db.query(models.LoaiPhong)
        .filter(models.LoaiPhong.building_id == building_id)
        .order_by(models.LoaiPhong.thu_tu, models.LoaiPhong.id)
        .all()
    )
    theo_hang: dict[int, list[models.Room]] = {h.id: [] for h in ds}
    chua_xep: list[models.Room] = []
    for p in phong:
        ma = getattr(p, "loai_phong_id", None)
        if ma in theo_hang:
            theo_hang[ma].append(p)
        else:
            chua_xep.append(p)

    ra_hang = []
    for h in ds:
        cua_hang = theo_hang[h.id]
        gia = {
            "gia_theo_gio": h.gia_theo_gio,
            "gia_qua_dem": h.gia_qua_dem,
            "gia_theo_ngay": h.gia_theo_ngay,
        }
        if cua_hang and any(v is None for v in gia.values()):
            k = (
                db.query(models.RoomKenh)
                .filter(
                    models.RoomKenh.room_id == cua_hang[0].id,
                    models.RoomKenh.kenh == models.RoomKenh.NGAN_HAN,
                )
                .first()
            )
            gia = gia_hieu_luc(k, h)
        ra_hang.append(_hang_ra(h, cua_hang, dang_o, gia))

    return {
        "building_id": building_id,
        "loai_phong": ra_hang,
        "chua_xep_hang": [
            {
                "id": p.id,
                "ma": p.code,
                "trang_thai": p.status,
                "co_khach": p.id in dang_o,
            }
            for p in chua_xep
        ],
        "tong_phong": len(phong),
    }


def tao(
    db: Session,
    uid: int,
    building_id: int,
    *,
    ten: str,
    mo_ta: Optional[str] = None,
    suc_chua: int = 2,
    dien_tich: Optional[float] = None,
    giuong: Optional[str] = None,
    anh: Optional[list[str]] = None,
    tien_nghi: Optional[list[str]] = None,
    gia_theo_gio: Optional[float] = None,
    gia_qua_dem: Optional[float] = None,
    gia_theo_ngay: Optional[float] = None,
    room_ids: Optional[list[int]] = None,
) -> models.LoaiPhong:
    _toa(db, uid, building_id)
    ten = _ten_sach(ten)
    if _trung_ten(db, building_id, ten):
        raise HTTPException(409, f'Toà này đã có hạng "{ten}"')
    lon_nhat = (
        db.query(models.LoaiPhong.thu_tu)
        .filter(models.LoaiPhong.building_id == building_id)
        .order_by(models.LoaiPhong.thu_tu.desc())
        .limit(1)
        .scalar()
    )
    hang = models.LoaiPhong(
        building_id=building_id,
        ten=ten,
        mo_ta=(mo_ta or "").strip() or None,
        suc_chua=max(1, int(suc_chua or 1)),
        dien_tich=dien_tich,
        giuong=(giuong or "").strip() or None,
        anh=anh or [],
        tien_nghi=tien_nghi or [],
        gia_theo_gio=gia_theo_gio,
        gia_qua_dem=gia_qua_dem,
        gia_theo_ngay=gia_theo_ngay,
        thu_tu=int(lon_nhat or 0) + 1,
    )
    db.add(hang)
    db.flush()
    if room_ids:
        gan_phong(db, uid, hang.id, room_ids)
    ap_gia_hang_vao_phong(db, hang)
    return hang


def sua(db: Session, uid: int, loai_id: int, **thay_doi) -> models.LoaiPhong:
    hang = _hang_cua_toi(db, uid, loai_id)
    if "ten" in thay_doi and thay_doi["ten"] is not None:
        ten = _ten_sach(thay_doi["ten"])
        if _trung_ten(db, hang.building_id, ten, tru=hang.id):
            raise HTTPException(409, f'Toà này đã có hạng "{ten}"')
        hang.ten = ten
    for khoa in (
        "mo_ta",
        "suc_chua",
        "dien_tich",
        "giuong",
        "anh",
        "tien_nghi",
        "gia_theo_gio",
        "gia_qua_dem",
        "gia_theo_ngay",
        "thu_tu",
        "dang_ban",
    ):
        if khoa in thay_doi and thay_doi[khoa] is not None:
            setattr(hang, khoa, thay_doi[khoa])
    db.flush()
    ap_gia_hang_vao_phong(db, hang)
    return hang


def xoa(db: Session, uid: int, loai_id: int) -> None:
    """Xoá hạng. Phòng thuộc hạng trở về "chưa xếp hạng", KHÔNG bị xoá theo."""
    hang = _hang_cua_toi(db, uid, loai_id)
    db.query(models.Room).filter(models.Room.loai_phong_id == hang.id).update(
        {models.Room.loai_phong_id: None}, synchronize_session=False
    )
    db.delete(hang)
    db.flush()


def gan_phong(db: Session, uid: int, loai_id: int, room_ids: list[int]) -> int:
    """Xếp đúng danh sách phòng này vào hạng; phòng cũ không còn trong danh sách
    thì trở về chưa xếp hạng. Gán là thao tác THAY THẾ, không phải cộng dồn —
    màn gán là một danh sách tích chọn, bỏ tích phải có tác dụng."""
    hang = _hang_cua_toi(db, uid, loai_id)
    hop_le = {
        p.id
        for p in db.query(models.Room)
        .filter(
            models.Room.building_id == hang.building_id,
            models.Room.id.in_(room_ids or [-1]),
        )
        .all()
    }
    la = set(room_ids or []) - hop_le
    if la:
        raise HTTPException(422, "Có phòng không thuộc toà nhà này")
    db.query(models.Room).filter(models.Room.loai_phong_id == hang.id).update(
        {models.Room.loai_phong_id: None}, synchronize_session=False
    )
    if hop_le:
        db.query(models.Room).filter(models.Room.id.in_(hop_le)).update(
            {models.Room.loai_phong_id: hang.id}, synchronize_session=False
        )
    db.flush()
    ap_gia_hang_vao_phong(db, hang)
    return len(hop_le)


def phong_trong_cua_loai(
    db: Session, loai_id: int, ci: datetime, co: datetime
) -> Optional[models.Room]:
    """Một phòng của hạng còn trống suốt [ci, co) — không có thì `None`.

    Luật bận dùng CHUNG với `chiem_dung_service.ghi`: hai khoảng đụng nhau khi
    `bắt đầu < kết thúc kia` và ngược lại, so theo GIỜ nếu dòng chiếm dụng có
    giờ, không thì coi như trọn ngày. Viết lại luật này ở đây khác đi là cảnh
    "hạng còn phòng" nhưng ghi đơn lại báo trùng.

    Trả phòng có mã nhỏ nhất để lễ tân gán phòng theo thứ tự dễ đoán.

    Giờ từ app có múi (+07:00) còn DB lưu giờ tường VN không múi: phải quy về
    một kiểu trước khi so, không thì hạng vừa có một đơn là đơn kế tiếp 500.
    """
    if ci.tzinfo is not None:
        ci = local_time(ci)
    if co.tzinfo is not None:
        co = local_time(co)
    phong = (
        db.query(models.Room)
        .filter(
            models.Room.loai_phong_id == loai_id,
            models.Room.status != "maintenance",
        )
        .order_by(models.Room.code.asc())
        .all()
    )
    for p in phong:
        ban = next(
            (
                r
                # Khoảng NGÀY phải bao trọn ca: ca 14h–17h cùng ngày thì
            # [ci.date(), co.date()) là khoảng rỗng, không dòng nào khớp.
            for r in chiem_dung_service.lich(
                db, p.id, ci.date(), co.date() + timedelta(days=1)
            )
                if (r.tu_luc or datetime.combine(r.tu_ngay, time())) < co
                and ci < (r.den_luc or datetime.combine(r.den_ngay, time()))
            ),
            None,
        )
        if ban is None:
            return p
    return None


def chon_phong_cho_ca(
    db: Session,
    uid: int,
    loai_id: int,
    *,
    kieu: str = "theo_gio",
    bat_dau: Optional[str] = None,
    so_luong: int = 1,
    la_admin: bool = False,
) -> models.Room:
    """Bốc phòng trống của LOẠI cho một ca sắp mở — hết phòng thì 409.

    Khoảng thời gian phải dựng theo cùng khuôn hẹn ca ngắn hạn, nếu không sẽ
    có cảnh "loại còn phòng" nhưng tới lúc ghi đơn thì báo trùng lịch.
    """
    x = db.get(models.LoaiPhong, loai_id)
    if x is None:
        raise HTTPException(404, "Hạng phòng không tồn tại")
    if not la_admin:
        _toa(db, uid, x.building_id)
    if not x.dang_ban:
        raise HTTPException(409, f'Loại "{x.ten}" đang tắt bán')
    now = local_now().replace(second=0, microsecond=0) + timedelta(minutes=1)
    ci = now
    if bat_dau:
        try:
            ci = datetime.fromisoformat(bat_dau).replace(second=0, microsecond=0)
        except ValueError:
            raise HTTPException(422, "Giờ bắt đầu không đúng dạng ISO")
        if ci < now:
            ci = now
    if kieu == "qua_dem":
        moc = ci.replace(hour=21, minute=0)
        if ci > moc:
            moc = moc + timedelta(days=1)
        ci, co = moc, moc.replace(hour=9) + timedelta(days=1)
    elif kieu == "theo_ngay":
        co = ci + timedelta(days=so_luong)
    else:
        co = ci + timedelta(hours=so_luong)

    phong = phong_trong_cua_loai(db, x.id, ci, co)
    if phong is None:
        raise HTTPException(409, f'Loại "{x.ten}" hết phòng trống trong khung giờ này')
    return phong
