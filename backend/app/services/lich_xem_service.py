"""Lịch xem phòng — neo vào đâu, ai được nhìn, ai được xử lý (R1 · R5 · R7).

## Vì sao tách ra khỏi router

Một lịch hẹn có tới BA người liên quan và họ đến từ ba bảng khác nhau:

    khách    = viewing_appointments.guest_id
    sale     = buildings.sale_id   (không phải houses.host_id — xem dưới)
    chủ nhà  = buildings.host_id   (chỉ lần ra được QUA phòng)

Bàn giao toà cố ý KHÔNG đổi `houses.host_id` (tin là của người ĐĂNG; đổi đi là
sale mất sạch hồ sơ uy tín dựng trên số tin). Hệ quả: quyền sở hữu tách đôi
giữa hai bảng, và câu "của tôi" phải nói rõ đang hỏi theo bảng nào. Đây chính
là chỗ R5 hỏng suốt: chủ nhà lọc theo `houses.host_id` nên không thấy gì.

## Quyết định nghiệp vụ đã chốt ở đây

**Chủ nhà THẤY, XÁC NHẬN được, và NHẬN ĐƯỢC SĐT khách.** Ban đầu tôi giấu số
khỏi chủ nhà để ép mọi liên lạc đi qua sale. Sai với việc thật: **người mở cửa
dẫn khách đi xem phòng chính là chủ nhà** — không có số thì họ không hẹn được
giờ, và cái "trung gian" ấy biến thành một khâu chuyển lời vô ích.

R1 bảo vệ HOA HỒNG và QUAN HỆ SỞ HỮU (`buildings.sale_id`, cổng R2 ở
`hosts_public`), không bảo vệ bằng cách cắt điện thoại giữa hai người phải gặp
nhau ngoài đời.
"""

from __future__ import annotations

from typing import Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session

from app import models
from app.services.building_sale_link import active_link
from app.services.sale_permissions import room_access_condition


class Neo:
    """Tin + phòng + toà của một lịch hẹn, đã tra đủ một lần."""

    def __init__(
        self,
        house: Optional[models.House] = None,
        room: Optional[models.Room] = None,
        building: Optional[models.Building] = None,
        sale_link: Optional[models.SaleOwnerLink] = None,
    ):
        self.house = house
        self.room = room
        self.building = building
        self.sale_link = sale_link

    @property
    def sale_id(self) -> Optional[int]:
        """Người khách nhìn thấy và liên hệ.

        Liên kết của toà quyết định sale; dữ liệu chưa liên kết dùng sale của
        phòng rồi toà. Chỉ tin lẻ mới dùng người đăng tin làm sale.
        """
        if self.sale_link is not None:
            return (
                self.sale_link.sale_id
                if self.building and self.building.host_id == self.sale_link.owner_id
                else None
            )
        if self.room is not None and self.room.managed_by_sale_id:
            return self.room.managed_by_sale_id
        if self.building is not None and self.building.sale_id:
            return self.building.sale_id
        if self.room is not None or self.building is not None:
            return None
        return self.house.host_id if self.house is not None else None

    @property
    def chu_nha_id(self) -> Optional[int]:
        """Người VẬN HÀNH phòng — chỉ tồn tại khi lịch lần ra được toà."""
        if self.room is not None and self.room.owner_id:
            return self.room.owner_id
        return self.building.host_id if self.building is not None else None

    @property
    def ten(self) -> str:
        if self.house is not None:
            return self.house.title
        if self.room is not None:
            return f"Phòng {self.room.code}"
        return "Phòng"


def tra_neo(
    db: Session,
    house_id: Optional[int] = None,
    room_id: Optional[int] = None,
) -> Neo:
    """Tra đủ tin/phòng/toà từ một trong hai đầu, tự bù đầu còn thiếu.

    Bù hai chiều là cố ý: lịch nào cũng nên mang cả `house_id` lẫn `room_id` khi
    biết được cả hai, để mọi truy vấn — theo tin hay theo toà — đều bắt được nó.
    Thiếu một đầu là một nhánh im lặng không trả về gì.
    """
    house = db.get(models.House, house_id) if house_id else None
    if room_id is None and house is not None:
        room_id = getattr(house, "source_room_id", None)
    room = db.get(models.Room, room_id) if room_id else None
    if house is None and room is not None and room.marketplace_house_id:
        house = db.get(models.House, room.marketplace_house_id)
    building = db.get(models.Building, room.building_id) if room else None
    return Neo(
        house=house,
        room=room,
        building=building,
        sale_link=active_link(db, building.id) if building else None,
    )


def neo_cua(db: Session, b: models.ViewingAppointment) -> Neo:
    return tra_neo(db, house_id=b.house_id, room_id=getattr(b, "room_id", None))


def duoc_xu_ly(db: Session, b: models.ViewingAppointment, claims: dict) -> bool:
    """Ai được duyệt / từ chối / chốt lịch này?

    Sale (người đăng tin hoặc sale phụ trách toà) và CHỦ NHÀ của toà. Chủ nhà
    phải có mặt ở đây, nếu không R5 vô nghĩa: yêu cầu bắn tới họ mà họ không
    bấm được gì.
    """
    if claims.get("role") == "admin":
        return True
    uid = claims.get("sub")
    n = neo_cua(db, b)
    ai = {n.sale_id, n.chu_nha_id}
    if n.building is not None:
        ai.add(n.building.host_id)
    return uid in {x for x in ai if x is not None}


class PhamViChu:
    """Phạm vi "lịch thuộc về tôi" của một người, ở vai người NHẬN lịch.

    Tính một lần rồi dùng cho cả bộ lọc lẫn việc quyết định có lộ SĐT khách —
    hai câu hỏi cùng cần đúng ba danh sách này, và hỏi lại từng dòng thì màn
    lịch 30 dòng thành 90 truy vấn.
    """

    def __init__(
        self,
        tin_ids: list[int],
        phong_ids: list[int],
        phong_sale_ids: list[int],
        tin_sale_ids: list[int],
    ):
        self.tin_ids = tin_ids
        self.tin_sale_ids = tin_sale_ids
        self.phong_ids = phong_ids
        self.phong_sale_ids = phong_sale_ids

    def dieu_kien(self):
        """Gộp hai vai vào một câu vì một người có thể mang cả hai (sale tự dựng
        dự án thì họ vừa là người đăng tin vừa đứng tên toà):

          1. lịch trên TIN của tôi          → `houses.host_id`
          2. lịch trên PHÒNG thuộc toà tôi  → `buildings.host_id` HOẶC `sale_id`
        """
        return or_(
            models.ViewingAppointment.house_id.in_(self.tin_ids or [-1]),
            models.ViewingAppointment.room_id.in_(self.phong_ids or [-1]),
        )

    def la_sale(self, b: models.ViewingAppointment) -> bool:
        """Tôi đang đứng ở vai SALE với lịch này (chứ không phải vai chủ nhà)?"""
        if b.house_id is not None and b.house_id in self.tin_sale_ids:
            return True
        room_id = getattr(b, "room_id", None)
        return room_id is not None and room_id in self.phong_sale_ids


def pham_vi_chu(db: Session, actor_id: int) -> PhamViChu:
    hang = (
        db.query(models.Room, models.Building, models.SaleOwnerLink)
        .select_from(models.Room)
        .join(models.Building, models.Building.id == models.Room.building_id)
        .outerjoin(
            models.SaleOwnerLink,
            (models.SaleOwnerLink.building_id == models.Building.id)
            & (models.SaleOwnerLink.status == "active"),
        )
        .filter(room_access_condition(actor_id))
        .all()
    )
    phong_ids = [room.id for room, _, _ in hang]
    phong_sale_ids = [
        room.id
        for room, building, link in hang
        if Neo(room=room, building=building, sale_link=link).sale_id == actor_id
    ]
    # Authorship of a linked listing is historical credit, not ongoing access.
    # Resolve both room-linked and older house-only appointments without N+1.
    houses = (
        db.query(models.House.id, models.House.source_room_id)
        .filter(
            or_(
                (models.House.host_id == actor_id) & models.House.source_room_id.is_(None),
                models.House.source_room_id.in_(phong_ids),
            )
        )
        .all()
    )
    return PhamViChu(
        tin_ids=[id for id, _ in houses],
        phong_ids=phong_ids,
        phong_sale_ids=phong_sale_ids,
        tin_sale_ids=[
            id for id, room_id in houses if room_id is None or room_id in phong_sale_ids
        ],
    )
