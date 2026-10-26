"""RoomRepository — host-scoped CRUD for rooms.

Note: Room doesn't have a direct host_id column; isolation is achieved via
the building_id join. We override _base_query to join buildings.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import HTTPException

from app import models
from app.services.sale_permissions import room_access_condition
from app.repositories.base import HostScopedRepository
from app.schemas.room import RoomCreate, RoomUpdate
from app.services import tien_ich_phong
from app.services.building_sale_link import active_link, lock_building


class RoomRepository(HostScopedRepository[models.Room]):
    model_class = models.Room
    # host_field_name not directly on Room — we override _base_query
    host_field_name = "host_id"  # unused, overridden below

    def _base_query(self):  # type: ignore[override]
        """Filter rooms by joining to buildings.host_id."""
        return (
            self.db.query(models.Room)
            .join(models.Building, models.Room.building_id == models.Building.id)
            .filter(room_access_condition(self.host_id))
        )

    def get(self, entity_id: int) -> Optional[models.Room]:
        return self._base_query().filter(models.Room.id == entity_id).first()

    def list(self, **filters) -> list[models.Room]:  # type: ignore[override]
        q = self._base_query()
        for key, value in filters.items():
            q = q.filter(getattr(models.Room, key) == value)
        return q.all()

    def list_by_building(self, building_id: int) -> list[models.Room]:
        """List all rooms in a building (host ownership already guaranteed by _base_query)."""
        return self._base_query().filter(models.Room.building_id == building_id).all()

    def create(self, building_id: int, payload: RoomCreate) -> models.Room:
        """Create and flush a new Room."""
        building = lock_building(self.db, building_id)
        # Recheck after the lock: a transfer may have revoked the caller while
        # this request waited behind it.
        if not (
            self.db.query(models.Building.id)
            .outerjoin(models.Room, models.Room.building_id == models.Building.id)
            .filter(models.Building.id == building_id, room_access_condition(self.host_id))
            .first()
        ):
            raise HTTPException(status_code=404, detail="Tòa nhà không tồn tại")
        link = active_link(self.db, building_id)
        now = datetime.utcnow()
        room = models.Room(
            building_id=building_id,
            managed_by_sale_id=link.sale_id if link else building.sale_id,
            code=payload.code,
            area_m2=payload.area_m2,
            capacity=payload.capacity,
            base_price=payload.base_price,
            status="vacant",
            images=payload.images,
            note=payload.note,
            gia_dien=payload.gia_dien,
            gia_nuoc=payload.gia_nuoc,
            phi_dich_vu=payload.phi_dich_vu,
            dich_vu_gom=tien_ich_phong.loc_dich_vu(payload.dich_vu_gom),
            do_trong_phong=tien_ich_phong.loc_do_dac(payload.do_trong_phong),
            tang=payload.tang,
            huong=payload.huong,
            created_at=now,
            updated_at=now,
        )
        self.db.add(room)
        self.db.flush()
        self._sinh_kenh(room, payload)
        return room

    def _sinh_kenh(self, room: models.Room, payload: RoomCreate) -> models.RoomKenh:
        """Mở kênh khai thác đầu tiên, TRONG CÙNG transaction với phòng.

        Trước migration 0104 chỗ này không tồn tại: phòng tạo qua form không
        thuộc kênh nào nên không ra chợ được, trong khi phòng sinh từ đường
        gán-tin (`host_building.py`) lại có kênh. Hai đường tạo phòng cho ra hai
        kết quả khác nhau, và chỉ một trong hai bán được hàng.

        Mặc định `dai_han` khi app không gửi `kenh` — app bản cũ nằm trong cache
        trình duyệt vẫn phải tạo được phòng dùng được.
        """
        kenh = payload.kenh or models.RoomKenh.DAI_HAN
        self.db.flush()  # chắc chắn room.id đã có trước khi tham chiếu
        dong = models.RoomKenh(
            room_id=room.id,
            kenh=kenh,
            gia=payload.base_price,
            don_vi=models.RoomKenh.DON_VI_MAC_DINH[kenh],
            toi_thieu=payload.toi_thieu,
            dat_coc=payload.dat_coc,
            # Kỳ miễn tiền sửa chữa là điều khoản của thuê thương mại. Để nó
            # lọt sang kênh khác thì màn hình kênh sẽ hiện một tham số vô nghĩa.
            mien_phi_thang=(
                payload.mien_phi_thang
                if kenh == models.RoomKenh.MAT_BANG
                else None
            ),
            dang_bat=True,
            created_at=room.created_at,
            updated_at=room.updated_at,
        )
        self.db.add(dong)
        self.db.flush()
        return dong

    def update(self, room: models.Room, payload: RoomUpdate) -> models.Room:
        data = payload.model_dump(exclude_unset=True)
        # Hai danh sách tick phải đi qua bộ lọc key, không gán thẳng: key lạ
        # lọt vào DB thì màn hình không dịch được sang nhãn và nó biến mất im
        # lặng khỏi giao diện, còn dữ liệu thì vẫn nằm đó.
        if "dich_vu_gom" in data:
            data["dich_vu_gom"] = tien_ich_phong.loc_dich_vu(data["dich_vu_gom"])
        if "do_trong_phong" in data:
            data["do_trong_phong"] = tien_ich_phong.loc_do_dac(
                data["do_trong_phong"]
            )
        for key, value in data.items():
            setattr(room, key, value)
        room.updated_at = datetime.utcnow()
        self.db.flush()
        return room

    def duplicate(self, room: models.Room) -> models.Room:
        """Clone a room with code suffix '_copy'."""
        building = lock_building(self.db, room.building_id)
        room = self._base_query().filter(models.Room.id == room.id).populate_existing().first()
        if room is None:
            raise HTTPException(status_code=404, detail="Phòng không tồn tại")
        link = active_link(self.db, room.building_id)
        now = datetime.utcnow()
        new_room = models.Room(
            building_id=room.building_id,
            managed_by_sale_id=(
                link.sale_id if link else (room.managed_by_sale_id or building.sale_id)
            ),
            code=f"{room.code}_copy",
            area_m2=room.area_m2,
            capacity=room.capacity,
            base_price=room.base_price,
            status="vacant",
            images=list(room.images) if room.images else [],
            note=room.note,
            gia_dien=room.gia_dien,
            gia_nuoc=room.gia_nuoc,
            phi_dich_vu=room.phi_dich_vu,
            dich_vu_gom=list(room.dich_vu_gom or []),
            do_trong_phong=list(room.do_trong_phong or []),
            tang=room.tang,
            huong=room.huong,
            created_at=now,
            updated_at=now,
        )
        self.db.add(new_room)
        self.db.flush()

        # Nhân bản CẢ KÊNH. Không chép thì phòng nhân bản ra không thuộc kênh
        # nào — tức là "nhân bản" cho ra một phòng không bán được, đúng thứ
        # người bấm nút không ngờ tới nhất.
        #
        # Trạng thái thì KHÔNG chép: bản gốc đã bán/đã cho thuê, bản sao là
        # hàng mới nên phải `dang_rao`.
        for k in (
            self.db.query(models.RoomKenh)
            .filter(models.RoomKenh.room_id == room.id)
            .order_by(models.RoomKenh.id)
            .all()
        ):
            self.db.add(
                models.RoomKenh(
                    room_id=new_room.id,
                    kenh=k.kenh,
                    gia=k.gia,
                    don_vi=k.don_vi,
                    toi_thieu=k.toi_thieu,
                    dat_coc=k.dat_coc,
                    mien_phi_thang=k.mien_phi_thang,
                    dang_bat=k.dang_bat,
                    trang_thai=models.RoomKenh.DANG_RAO,
                    created_at=now,
                    updated_at=now,
                )
            )
        self.db.flush()
        return new_room
