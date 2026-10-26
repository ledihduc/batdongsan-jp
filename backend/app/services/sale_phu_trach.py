"""AI được ghi công cho một phòng / một tin? (luật R6)

## Vì sao cần một nơi duy nhất trả lời

Trước 08/09/2026 câu này được trả lời ở ba chỗ với ba câu trả lời khác nhau:

    deals.py (nhánh phòng)  →  rooms.managed_by_sale_id
    deals.py (nhánh tin)    →  houses.host_id          ← SAI khi chủ nhà tự đăng
    reservation_service.py  →  rooms.managed_by_sale_id

Nhánh `houses.host_id` chạy đúng chỉ vì bàn giao KHÔNG đổi `houses.host_id`, nên
tin do sale đăng vẫn mang tên sale. Nhưng khi CHỦ NHÀ tự đăng tin phòng của mình
thì `houses.host_id` là chủ nhà — và công của sale bị ghi cho chủ nhà. Đúng thứ
R2 nói là không được: quan hệ với chủ nhà là tài sản của sale tìm ra họ.

## Thứ tự tra

1. Liên kết active của TOÀ quyết định sale cho mọi phòng trong toà đó.
2. Toà chưa có liên kết scoped: giữ sale của phòng, rồi sale của toà.
3. Không có sale → để trống, không rơi về chủ nhà.

Bước 3 là chỗ dễ sai nhất. Rơi về chủ nhà nghe có vẻ "an toàn" nhưng nó ghi
công bán hàng cho người KHÔNG bán, và làm hỏng đúng con số mà sale ở lại nền
tảng vì nó. Không có sale thì để trống — trống là một câu trả lời đúng.

Tin LẺ (không thuộc dự án nào) là loại đối tượng khác: không có toà, không có
chủ nhà nào khác, người đăng đúng là người dẫn được khách về. Đó không phải
nhánh dự phòng của bước 1.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy.orm import Session

from app import models


def sale_cua_phong(db: Session, room: Optional[models.Room]) -> Optional[int]:
    """Sale của toà đã liên kết; phòng/toà dự phòng cho dữ liệu chưa liên kết."""
    if room is None:
        return None
    from app.services.building_sale_link import active_link

    link = active_link(db, room.building_id)
    if link:
        building = db.get(models.Building, room.building_id)
        return link.sale_id if building and building.host_id == link.owner_id else None
    if room.managed_by_sale_id:
        return room.managed_by_sale_id
    toa = (
        db.query(models.Building)
        .filter(models.Building.id == room.building_id)
        .first()
    )
    return toa.sale_id if toa is not None else None


def sale_cua_tin(db: Session, house: Optional[models.House]) -> Optional[int]:
    """Sale được ghi công cho tin này.

    Tin sinh từ phòng (`source_room_id`) thì hỏi phòng — vì sau bàn giao chính
    chủ nhà cũng đăng được tin cho phòng của họ, và lúc đó `host_id` không còn
    là sale nữa.
    """
    if house is None:
        return None
    room_id = getattr(house, "source_room_id", None)
    if room_id:
        phong = db.query(models.Room).filter(models.Room.id == room_id).first()
        if phong is not None:
            return sale_cua_phong(db, phong)
    return house.host_id


def chu_cua_phong(db: Session, room: Optional[models.Room]) -> Optional[int]:
    """Chủ phòng — người nhận tiền và là người XÁC NHẬN giao dịch.

    `rooms.owner_id` trước, `buildings.host_id` sau: một dự án chứa được phòng
    của nhiều chủ, nên chủ nằm ở phòng chứ không suy từ toà.
    """
    if room is None:
        return None
    if room.owner_id:
        return room.owner_id
    toa = (
        db.query(models.Building)
        .filter(models.Building.id == room.building_id)
        .first()
    )
    return toa.host_id if toa else None


def duoc_thao_tac_phong(
    db: Session, room: Optional[models.Room], uid: int, la_admin: bool = False
) -> bool:
    """Ai được đổi giá / chốt phòng này?

    Chủ phòng, chủ toà, admin — và **đúng một sale**: người đang phụ trách phòng
    theo `sale_cua_phong`. Liên kết scoped quyết định sale cho cả toà; chỉ dữ
    liệu chưa có liên kết mới dùng sale riêng của phòng làm dự phòng.
    """
    if room is None:
        return False
    if la_admin:
        return True
    if uid == room.owner_id:
        return True
    toa = (
        db.query(models.Building)
        .filter(models.Building.id == room.building_id)
        .first()
    )
    if toa is not None and uid == toa.host_id:
        return True
    return uid == sale_cua_phong(db, room)
