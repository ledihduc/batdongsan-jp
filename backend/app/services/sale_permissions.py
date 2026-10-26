"""Kiểm quyền sale ↔ chủ phòng ↔ khách — MỘT chỗ duy nhất.

Spec mục 4: *"Backend phải kiểm tra quyền từ dữ liệu liên kết. Không nhận
sale_id hoặc owner_id từ app rồi tin trực tiếp."*

Vì sao gom về một tệp thay vì viết điều kiện lọc ở từng router: dự án này có
hơn 40 router; chỗ nào quên một điều kiện là chỗ đó rò dữ liệu, và không ai
phát hiện được cho tới khi có người dò. Ở đây chỉ có một hàm để đọc và một bộ
test để bảo vệ.

Bất biến KHÔNG có ngoại lệ:
  - `tai_chinh` luôn False với sale. Hoá đơn, thanh toán, công nợ là của chủ
    phòng. Kể cả sale đang quản lý phòng đó.
  - Quyền của sale chỉ tồn tại khi liên kết còn `active`. Ngắt liên kết là mất
    quyền ngay lượt gọi sau, không cần dọn dẹp gì thêm.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from sqlalchemy.orm import Session
from sqlalchemy import and_, exists, or_

from app import models


@dataclass(frozen=True)
class QuyenPhong:
    """Người này làm được gì với phòng này."""

    doc: bool = False
    sua_noi_dung: bool = False  # ảnh, mô tả, giá đăng, tiện ích
    sua_trang_thai: bool = False  # trống / đang giữ / đã đặt
    tai_chinh: bool = False  # hợp đồng, hoá đơn, thanh toán, công nợ

    # Ai đang nhìn: 'owner' | 'sale' | 'admin' | None
    vai: Optional[str] = None

    @property
    def khong_co_gi(self) -> bool:
        return not (self.doc or self.sua_noi_dung or self.sua_trang_thai)


KHONG = QuyenPhong()


def room_access_condition(actor_id: int):
    """SQL scope for queries joining Room and Building.

    A scoped link overrides legacy room/building sale assignments. No link
    means existing assignments still support projects awaiting handover.
    """
    linked = (
        exists()
        .where(
            models.SaleOwnerLink.building_id == models.Building.id,
            models.SaleOwnerLink.status == "active",
        )
        .correlate(models.Building)
    )
    own_link = (
        exists()
        .where(
            models.SaleOwnerLink.building_id == models.Building.id,
            models.SaleOwnerLink.owner_id == models.Building.host_id,
            models.SaleOwnerLink.sale_id == actor_id,
            models.SaleOwnerLink.status == "active",
        )
        .correlate(models.Building)
    )
    return or_(
        models.Building.host_id == actor_id,
        models.Room.owner_id == actor_id,
        own_link,
        and_(
            ~linked,
            or_(
                models.Building.sale_id == actor_id,
                models.Room.managed_by_sale_id == actor_id,
            ),
        ),
    )


def lien_ket_active(db: Session, *, sale_id: int, owner_id: int, building_id: int) -> bool:
    """Quyền chỉ áp dụng cho đúng toà đang thuộc chủ đã liên kết."""
    return (
        db.query(models.SaleOwnerLink.id)
        .join(models.Building, models.Building.id == models.SaleOwnerLink.building_id)
        .filter(
            models.SaleOwnerLink.building_id == building_id,
            models.Building.host_id == owner_id,
            models.SaleOwnerLink.sale_id == sale_id,
            models.SaleOwnerLink.owner_id == owner_id,
            models.SaleOwnerLink.status == "active",
        )
        .first()
        is not None
    )


def chu_cua_sale(db: Session, sale_id: int) -> list[int]:
    """Danh sách chủ phòng đang liên kết với một sale."""
    return [
        r[0]
        for r in db.query(models.SaleOwnerLink.owner_id)
        .join(models.Building, models.Building.id == models.SaleOwnerLink.building_id)
        .filter(
            models.Building.host_id == models.SaleOwnerLink.owner_id,
            models.SaleOwnerLink.sale_id == sale_id,
            models.SaleOwnerLink.status == "active",
        )
        .distinct()
        .all()
    ]


def quyen_phong(
    db: Session,
    *,
    actor_id: int,
    actor_role: str,
    room: models.Room,
) -> QuyenPhong:
    """Quyền của `actor_id` trên `room`.

    Thứ tự xét quan trọng: admin trước, rồi chủ sở hữu, rồi sale quản lý. Một
    người có thể vừa là chủ vừa là sale của chính mình — khi đó quyền CHỦ thắng
    (rộng hơn), không cộng dồn hai nhánh.
    """
    if actor_role == "admin":
        return QuyenPhong(
            doc=True,
            sua_noi_dung=True,
            sua_trang_thai=True,
            tai_chinh=True,
            vai="admin",
        )

    owner_id = getattr(room, "owner_id", None)
    from app.services.sale_phu_trach import sale_cua_phong

    sale_id = sale_cua_phong(db, room)

    toa = db.get(models.Building, room.building_id)
    if owner_id is None:
        owner_id = toa.host_id if toa else None

    if owner_id is not None and actor_id == owner_id:
        return QuyenPhong(
            doc=True,
            sua_noi_dung=False,  # chủ phòng YÊU CẦU sửa, không tự sửa nội dung
            sua_trang_thai=True,
            tai_chinh=True,
            vai="owner",
        )

    if (
        sale_id is not None
        and actor_id == sale_id
        and toa is not None
        and lien_ket_active(db, sale_id=actor_id, owner_id=toa.host_id, building_id=toa.id)
    ):
        return QuyenPhong(
            doc=True,
            sua_noi_dung=True,
            sua_trang_thai=True,
            # Bất biến: sale KHÔNG bao giờ chạm tài chính.
            tai_chinh=False,
            vai="sale",
        )

    # Sale tự dựng phòng khi chưa gán chủ: chưa có owner_id thì người tạo toà
    # chính là người quản lý.
    if owner_id is not None and sale_id is None and actor_id == owner_id:
        return QuyenPhong(doc=True, sua_noi_dung=True, sua_trang_thai=True, vai="sale")

    return KHONG
