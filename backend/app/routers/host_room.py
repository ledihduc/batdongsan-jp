"""Room management endpoints.

Mọi endpoint dùng `require_user` chứ KHÔNG phải `require_host`: sale là tài
khoản thường (role='guest') nhưng chính họ là người dựng dự án và đăng phòng
trước khi tìm được chủ nhà. Cách ly quyền KHÔNG dựa vào role mà dựa vào
`RoomRepository` join sang `buildings.host_id` — mở role ra không nới quyền truy cập dữ liệu của người khác.

Endpoints:
    GET  /api/host/buildings/{id}/rooms   — list rooms in a building
    POST /api/host/buildings/{id}/rooms   — create room
    PATCH /api/host/rooms/{id}            — update room fields
    POST /api/host/rooms/{id}/duplicate   — D5 1-click clone
    POST /api/host/rooms/{id}/maintenance — set maintenance window
    POST /api/host/rooms/{id}/maintenance/end — clear maintenance
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.orm import Session

from app import auth, models
from app.services import gia_tien_ich, so_phong
from app.services.sale_permissions import room_access_condition
from app.database import get_db
from app.repositories.room_repository import RoomRepository
from app.schemas.room import (
    MaintenanceSetRequest,
    RoomCreate,
    RoomResponse,
    RoomUpdate,
)
from app.services.room_state_service import clear_maintenance, set_maintenance

router = APIRouter(prefix="/api/host", tags=["host-room"])


def _toa_co_quyen(db: Session, building_id: int, uid: int):
    return (db.query(models.Building)
        .outerjoin(models.Room, models.Room.building_id == models.Building.id)
        .filter(models.Building.id == building_id,
                room_access_condition(uid))
        .first())


def _ra(db: Session, room: models.Room) -> RoomResponse:
    """Gắn thêm giá ĐÃ GIẢI QUYẾT (phòng → toà → hằng số) vào phản hồi.

    App cần cả hai: ba cột thô để biết ô nhập nên để trống hay điền sẵn, và ba
    số hiệu lực để hiển thị. Bắt app tự suy thứ tự ưu tiên là tạo ra bản sao
    thứ hai của cùng một luật — lệch nhau lúc nào không ai biết.
    """
    ra = RoomResponse.model_validate(room)
    ra.gia_dien_hieu_luc = gia_tien_ich.gia_dien(db, room)
    ra.gia_nuoc_hieu_luc = gia_tien_ich.gia_nuoc(db, room)
    ra.phi_dich_vu_hieu_luc = gia_tien_ich.phi_dich_vu(db, room)
    return ra


@router.get("/buildings/{building_id}/rooms", response_model=list[RoomResponse])
def list_rooms(
    building_id: int,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> list[RoomResponse]:
    uid = claims["sub"]
    toa = _toa_co_quyen(db, building_id, uid)
    if not toa:
        raise HTTPException(status_code=404, detail="Tòa nhà không tồn tại")
    room_repo = RoomRepository(db, host_id=uid)
    rooms = room_repo.list_by_building(building_id)
    la_admin = claims.get("role") == "admin"

    def xem_khach(p: models.Room) -> bool:
        # Tên khách và hạn hợp đồng là dữ liệu của CHỦ phòng — một luật duy
        # nhất ở `so_phong.duoc_xem_tai_chinh`, dùng chung với hồ sơ phòng.
        return so_phong.duoc_xem_tai_chinh(p, toa.host_id, uid, la_admin)

    so = so_phong.tinh_trang_phong(db, rooms, duoc_xem_khach=xem_khach)
    ra = []
    for r in rooms:
        x = _ra(db, r)
        for k, v in so[r.id].items():
            setattr(x, k, v)
        ra.append(x)
    return ra


@router.post("/buildings/{building_id}/rooms", response_model=RoomResponse, status_code=201)
def create_room(
    building_id: int,
    body: RoomCreate,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> RoomResponse:
    if not _toa_co_quyen(db, building_id, claims["sub"]):
        raise HTTPException(status_code=404, detail="Tòa nhà không tồn tại")
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.create(building_id, body)
    db.commit()
    db.refresh(room)
    return _ra(db, room)


@router.patch("/rooms/{room_id}", response_model=RoomResponse)
def update_room(
    room_id: int,
    body: RoomUpdate,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> RoomResponse:
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    updated = room_repo.update(room, body)
    db.commit()
    db.refresh(updated)
    return _ra(db, updated)


@router.delete("/rooms/{room_id}", status_code=204, response_class=Response)
def xoa_phong(
    room_id: int,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    """Xoá một phòng — CHỈ khi nó chưa dính gì tới tiền hay tới người.

    Tới trước hôm nay không có đường xoá nào: phòng gõ nhầm mã, phòng dựng thử,
    phòng của toà đã bán — đều nằm lại vĩnh viễn trong sổ và trên chợ.

    Ba cổng chặn, xếp theo mức khó gỡ:

    1. **Hợp đồng** — `contracts.room_id` là FK RESTRICT. Xoá được thì hoá đơn
       và công nợ của người thuê mất chỗ bám.
    2. **Đơn đặt phòng** — `reservations.room_id` cũng RESTRICT, và khách đang
       giữ một mã đặt phòng có thật.
    3. **Đang bị chiếm lịch** — hợp đồng/đơn/khoá tay còn hiệu lực.

    Không soft-delete: `rooms` chưa có cột nào cho việc đó, và thêm một cột
    `is_deleted` nghĩa là phải soi lại MỌI truy vấn đang đọc bảng này. Chặn
    trước rồi xoá thật thì không để lại phần nợ ấy.
    """
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")

    if db.query(models.Contract.id).filter(
        models.Contract.room_id == room_id
    ).first():
        raise HTTPException(409, "Phòng đã có hợp đồng, không xoá được.")

    if db.query(models.Reservation.id).filter(
        models.Reservation.room_id == room_id
    ).first():
        raise HTTPException(409, "Phòng đã có đơn đặt, không xoá được.")

    if db.query(models.RoomChiemDung.id).filter(
        models.RoomChiemDung.room_id == room_id
    ).first():
        raise HTTPException(409, "Phòng đang có lịch, gỡ lịch trước khi xoá.")

    # Kênh khai thác và tin đã đăng: gỡ theo phòng chứ không để FK tự quyết.
    # `room_kenh` CASCADE nên tự đi, nhưng tin trên chợ thì phải cắt dây trước —
    # để nguyên là tin trỏ vào một phòng không còn tồn tại.
    db.query(models.House).filter(
        models.House.source_room_id == room_id
    ).update({"source_room_id": None}, synchronize_session=False)
    # Xoá kênh TƯỜNG MINH dù FK đã là CASCADE: SQLite (test) không bật kiểm FK
    # nên nếu chỉ dựa vào cascade thì test xanh mà không chứng minh được gì.
    db.query(models.RoomKenh).filter(
        models.RoomKenh.room_id == room_id
    ).delete(synchronize_session=False)
    db.delete(room)
    db.commit()
    return Response(status_code=204)


@router.post("/rooms/{room_id}/duplicate", response_model=RoomResponse, status_code=201)
def duplicate_room(
    room_id: int,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> RoomResponse:
    """D5: 1-click clone a room. New room gets code+`_copy`, status=vacant."""
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    new_room = room_repo.duplicate(room)
    db.commit()
    db.refresh(new_room)
    return _ra(db, new_room)


@router.post("/rooms/{room_id}/maintenance", response_model=RoomResponse)
def set_room_maintenance(
    room_id: int,
    body: MaintenanceSetRequest,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> RoomResponse:
    """Set room status to maintenance with start/end dates."""
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    # room_state_service validates transition and raises 400 on invalid
    set_maintenance(room, body.maintenance_start, body.maintenance_end)
    from datetime import datetime
    room.updated_at = datetime.utcnow()
    db.flush()
    db.commit()
    db.refresh(room)
    return _ra(db, room)


@router.post("/rooms/{room_id}/maintenance/end", response_model=RoomResponse)
def end_room_maintenance(
    room_id: int,
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
) -> RoomResponse:
    """Clear room maintenance window, return to vacant."""
    room_repo = RoomRepository(db, host_id=claims["sub"])
    room = room_repo.get(room_id)
    if not room:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    clear_maintenance(room)
    from datetime import datetime
    room.updated_at = datetime.utcnow()
    db.flush()
    db.commit()
    db.refresh(room)
    return _ra(db, room)
