"""TIN NGẮN HẠN NEO VÀO HẠNG PHÒNG, không neo vào một phòng lẻ (23/09/2026).

Khách sạn và homestay bán HẠNG: khách đặt "Deluxe hướng vườn", lễ tân gán số
phòng lúc nhận. Trước đây chợ neo tin vào `houses.source_room_id` — mười phòng
giống hệt nhau thành mười tin trùng, và "hạng này còn mấy phòng" là câu không
ai trả lời được.

Dài hạn thì ngược lại: thuê tháng là thuê ĐÚNG căn đó, khách đi xem chính căn
đó — neo theo phòng mới đúng. Hai trục khác nhau, đừng ép về một.

Ở đây gom ba việc:
  * `kenh_cua_danh_muc` — pipeline của tin suy từ nhóm danh mục, KHÔNG để tin
    homestay rơi vào pipeline dài hạn như trước;
  * `neo_hang` — gắn tin vào hạng (kèm kiểm quyền trên toà);
  * `thong_tin_hang` — hạng + còn mấy phòng + giá, cho màn chi tiết tin;
  * `phong_cho_don` — bốc phòng trống của hạng khi khách chốt đặt.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.services import loai_phong_service
from app.services.sale_permissions import room_access_condition

#: Nhóm danh mục → pipeline của tin. Nhóm nào không có ở đây thì là dài hạn.
_KENH_THEO_NHOM = {
    "stay_short": models.RoomKenh.NGAN_HAN,
    "business": models.RoomKenh.MAT_BANG,
    "stay_long": models.RoomKenh.DAI_HAN,
}


def kenh_cua_danh_muc(
    db: Session, category_id: Optional[int], transaction_type: str
) -> str:
    """Pipeline của tin MỚI.

    Bán thắng mọi thứ (trục giao dịch). Còn lại suy từ `categories.group_key`:
    trước 23/09/2026 `create_house` không hề đụng cột `kenh`, nên tin Homestay
    vẫn nằm pipeline `dai_han` — chốt một hợp đồng thuê tháng là đóng nhầm cả
    tin khách sạn của cùng phòng.
    """
    if (transaction_type or "") == "sale":
        return models.RoomKenh.BAN
    dm = db.get(models.Category, category_id) if category_id else None
    nhom = getattr(dm, "group_key", None) or ""
    return _KENH_THEO_NHOM.get(nhom, models.RoomKenh.DAI_HAN)


def hang_duoc_neo(db: Session, uid: int, loai_phong_id: int) -> models.LoaiPhong:
    """Hạng mà người đăng được phép neo tin vào — không thì 404.

    Dùng đúng `room_access_condition` của sổ phòng: chủ toà, chủ phòng, hoặc
    sale đang phụ trách. Tự viết lại luật quyền ở đây là một ngày nào đó sale
    bị gỡ vẫn neo được tin vào toà cũ.
    """
    hang = db.get(models.LoaiPhong, loai_phong_id)
    if hang is None:
        raise HTTPException(404, "Hạng phòng không tồn tại")
    duoc = (
        db.query(models.Building.id)
        .outerjoin(models.Room, models.Room.building_id == models.Building.id)
        .filter(models.Building.id == hang.building_id, room_access_condition(uid))
        .first()
    )
    if duoc is None:
        raise HTTPException(404, "Hạng phòng không thuộc toà bạn quản lý")
    return hang


def neo_hang(db: Session, house: models.House, uid: int, loai_phong_id: int) -> None:
    """Kiểm quyền rồi gắn tin vào hạng."""
    gan_hang(db, house, hang_duoc_neo(db, uid, loai_phong_id))


def gan_hang(db: Session, house: models.House, hang: models.LoaiPhong) -> None:
    """Gắn tin vào hạng ĐÃ kiểm quyền. Tin ngắn hạn KHÔNG giữ `source_room_id`."""
    house.loai_phong_id = hang.id
    house.source_room_id = None
    # Số phòng của hạng chính là tồn kho của tin — không bắt người đăng gõ lại.
    tong = so_phong_cua_hang(db, hang.id)
    house.listing_type = "multi_unit" if tong > 1 else "single"
    house.total_units = max(tong, 1)
    house.available_units = max(tong, 1)


def so_phong_cua_hang(db: Session, loai_phong_id: int) -> int:
    return (
        db.query(models.Room)
        .filter(
            models.Room.loai_phong_id == loai_phong_id,
            models.Room.status != "maintenance",
        )
        .count()
    )


def so_phong_trong_hom_nay(db: Session, loai_phong_id: int) -> int:
    """Số phòng của hạng KHÔNG bận trong hôm nay — tồn kho hiện tại của tin.

    Một truy vấn `NOT EXISTS` thay vì lặp từng phòng: khối này nằm trong payload
    tin, mà feed trả về hàng chục tin một lượt.

    Ngày chứ không phải giờ: chợ chỉ cần "hạng này còn hàng hôm nay"; còn đặt
    được đúng khung giờ nào thì lịch bận (`lich-ban`) và `phong_cho_don` mới là
    nơi trả lời — và hai chỗ đó dùng chung luật bận với quầy lễ tân.
    """
    from datetime import date as _date

    hom_nay = _date.today()
    ban = (
        db.query(models.RoomChiemDung.id)
        .filter(
            models.RoomChiemDung.room_id == models.Room.id,
            models.RoomChiemDung.tu_ngay <= hom_nay,
            models.RoomChiemDung.den_ngay > hom_nay,
        )
        .exists()
    )
    return (
        db.query(models.Room)
        .filter(
            models.Room.loai_phong_id == loai_phong_id,
            models.Room.status != "maintenance",
            ~ban,
        )
        .count()
    )


def thong_tin_hang(db: Session, house: models.House) -> Optional[dict]:
    """Khối "hạng phòng" cho màn chi tiết tin. `None` nếu tin không neo hạng."""
    ma = getattr(house, "loai_phong_id", None)
    if not ma:
        return None
    hang = db.get(models.LoaiPhong, ma)
    if hang is None:
        return None
    toa = db.get(models.Building, hang.building_id)
    tong = so_phong_cua_hang(db, hang.id)
    gia = loai_phong_service.gia_hieu_luc(None, hang)
    return {
        "con_trong": so_phong_trong_hom_nay(db, hang.id),
        "id": hang.id,
        "ten": hang.ten,
        "mo_ta": hang.mo_ta,
        "suc_chua": hang.suc_chua,
        "dien_tich": hang.dien_tich,
        "giuong": hang.giuong,
        "anh": list(hang.anh or []),
        "tien_nghi": list(hang.tien_nghi or []),
        "dang_ban": bool(hang.dang_ban),
        "so_phong": tong,
        "gia_theo_gio": gia["gia_theo_gio"],
        "gia_qua_dem": gia["gia_qua_dem"],
        "gia_theo_ngay": gia["gia_theo_ngay"],
        "toa": (
            {"id": toa.id, "ten": toa.name, "dia_chi": toa.address}
            if toa is not None
            else None
        ),
    }


def giao_cac_khoang(nhom: list[list[dict]]) -> list[dict]:
    """GIAO của các danh sách khoảng bận — hạng bận khi MỌI phòng đều bận.

    Mỗi phần tử là `{"tu": iso, "den": iso}` như `phieu_dat_phong.lich_ban`.
    Lấy hợp thay vì giao là tự bỏ hàng còn bán được: một phòng bận mà hạng còn
    phòng khác thì khách vẫn đặt được.
    """
    if not nhom:
        return []
    ket = [(m["tu"], m["den"]) for m in nhom[0]]
    for ds in nhom[1:]:
        moi = []
        for a_tu, a_den in ket:
            for m in ds:
                tu = max(a_tu, m["tu"])
                den = min(a_den, m["den"])
                if tu < den:
                    moi.append((tu, den))
        ket = moi
        if not ket:
            return []
    ket.sort()
    return [{"tu": a, "den": b} for a, b in ket]


def phong_cho_don(
    db: Session, house: models.House, ci: datetime, co: datetime
) -> models.Room:
    """Bốc một phòng trống của hạng cho đơn sắp ghi — hết thì 409.

    Dùng chung `loai_phong_service.phong_trong_cua_loai` với quầy lễ tân, để
    "còn trống" ở chợ và ở quầy không bao giờ nói hai con số khác nhau.
    """
    ma = getattr(house, "loai_phong_id", None)
    if not ma:
        raise HTTPException(409, "Tin này không neo hạng phòng")
    hang = db.get(models.LoaiPhong, ma)
    if hang is None:
        raise HTTPException(409, "Hạng phòng đã bị xoá")
    if not hang.dang_ban:
        raise HTTPException(409, f'Hạng "{hang.ten}" đang tạm ngừng nhận khách')
    phong = loai_phong_service.phong_trong_cua_loai(db, hang.id, ci, co)
    if phong is None:
        raise HTTPException(409, f'Hạng "{hang.ten}" hết phòng trong khung giờ này')
    return phong
