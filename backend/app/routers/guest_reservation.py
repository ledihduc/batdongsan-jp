"""Guest-facing reservation endpoints (Phase 07 — marketplace book flow).

POST /api/guest/reservations
    Logged-in guest books a homestay room. Server resolves host_id from room.
    Creates reservation in 'pending' state; host approves separately.

GET  /api/guest/reservations
    List my reservations (as guest).

POST /api/guest/reservations/{id}/cancel
    Guest cancels their own reservation. Refund computed per policy.
"""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db
from app.schemas.reservation import (
    ReservationCancel,
    ReservationCreate,
    ReservationResponse,
)
from app.services import (
    lich_su_dat,
    phieu_dat_phong,
    reservation_service,
    sale_phu_trach,
    short_stay_service,
    sua_dat_cho,
)
from app.status_realtime import publish_status_change

router = APIRouter(prefix="/api/guest/reservations", tags=["guest-reservation"])


def _serialise(res: models.Reservation, db: Session) -> ReservationResponse:
    room = db.get(models.Room, res.room_id)
    room_code = room.code if room else None
    building_name = None
    if room is not None:
        b = db.get(models.Building, room.building_id)
        building_name = b.name if b else None
    return ReservationResponse(
        **short_stay_service.response_fields(res),
        id=res.id,

        room_id=res.room_id,
        guest_user_id=res.guest_user_id,
        guest_name=res.guest_name,
        guest_phone=res.guest_phone,
        guest_email=res.guest_email,
        check_in_date=res.check_in_date,
        check_out_date=res.check_out_date,
        nights=res.nights,
        total_amount=res.total_amount,
        deposit_paid=res.deposit_paid,
        activity_deposit_policy_version=res.activity_deposit_policy_version,
        activity_primary_deposit_bps=res.activity_primary_deposit_bps,
        activity_primary_deposit_amount=res.activity_primary_deposit_amount,
        status=res.status,
        cancel_policy_snapshot=res.cancel_policy_snapshot,
        cancelled_at=res.cancelled_at,
        refund_amount=res.refund_amount,
        rejection_reason=res.rejection_reason,
        source=res.source,
        note=res.note,
        created_at=res.created_at,
        updated_at=res.updated_at,
        room_code=room_code,
        building_name=building_name,
    )


@router.post("", response_model=ReservationResponse, response_model_exclude_none=True, status_code=201)
def create_my_reservation(
    payload: ReservationCreate,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Guest books a room. Server pins guest_user_id from JWT for auditability."""
    guest_user_id = claims["sub"]
    room = db.get(models.Room, payload.room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    building = db.get(models.Building, room.building_id)
    if building is None:
        raise HTTPException(status_code=404, detail="Toà nhà không tồn tại")

    # CỔNG KÊNH — đặt theo ĐÊM chỉ dành cho phòng có bật kênh 'ngan_han'.
    #
    # Trước 08/09/2026 chỗ này chỉ kiểm phòng và toà nhà CÓ TỒN TẠI. Nên một căn
    # hộ cho thuê 5.500.000đ/THÁNG đặt được theo đêm, và màn đặt phòng nhân giá
    # tháng với số đêm: 3 đêm = 16.500.000đ. Đây là lỗi TÍNH TIỀN, không phải
    # lỗi giao diện — nên phải chặn ở đây, không chỉ ẩn nút ở app.
    kenh = (
        db.query(models.RoomKenh)
        .filter(
            models.RoomKenh.room_id == room.id,
            models.RoomKenh.kenh == models.RoomKenh.NGAN_HAN,
            models.RoomKenh.dang_bat.is_(True),
        )
        .first()
    )
    if kenh is None:
        raise HTTPException(
            status_code=409,
            detail="Phòng này không cho thuê theo đêm. Liên hệ chủ nhà để thuê dài hạn.",
        )
    if payload.booking_mode is None and (
        short_stay_service.products(kenh) or not kenh.gia or kenh.gia <= 0
        or kenh.don_vi != "dem"
    ):
        raise HTTPException(422, "Vui lòng chọn theo giờ, qua đêm hoặc theo ngày và xem giá trước khi đặt")
    if kenh.toi_thieu and payload.booking_mode is None:
        # Số đêm tối thiểu là tham số của KÊNH, không phải của phòng — mỗi kênh
        # một ngưỡng riêng.
        from app.services.reservation_service import _validate_dates

        if _validate_dates(payload.check_in_date, payload.check_out_date) < kenh.toi_thieu:
            raise HTTPException(
                status_code=422,
                detail=f"Phòng này đặt tối thiểu {kenh.toi_thieu} đêm.",
            )

    # CỔNG SALE — khách KHÔNG đặt thẳng với chủ nhà (luật chủ dự án 14/09/2026).
    #
    # Đường vào hợp lệ là tin của sale, hoặc trang toà của sale → chọn phòng.
    # Cả hai đều quy về MỘT câu hỏi: phòng này có sale phụ trách không? Sale do
    # server tự xác định bằng `sale_cua_phong` (luật R6) chứ không nhận từ app —
    # nhận từ app là để ai cũng tự ghi công cho mình được.
    #
    # Không có sale → từ chối. Sale trùng chính chủ phòng cũng từ chối: đó vẫn
    # là đặt thẳng với chủ nhà, chỉ đổi tên gọi.
    sale_id = sale_phu_trach.sale_cua_phong(db, room)
    chu_id = sale_phu_trach.chu_cua_phong(db, room)
    if sale_id is None or sale_id == chu_id:
        raise HTTPException(
            status_code=409,
            detail=(
                "Phòng này chưa có sale phụ trách nên chưa nhận đặt trực tuyến. "
                "Vui lòng đặt qua tin đăng hoặc trang toà nhà của sale."
            ),
        )
    if payload.so_khach is not None:
        if payload.so_khach < 1:
            raise HTTPException(422, "Số khách phải từ 1 người")
        if room.capacity and payload.so_khach > room.capacity:
            raise HTTPException(422, f"Phòng này ở tối đa {room.capacity} khách")
    if payload.house_id is not None:
        tin = db.get(models.House, payload.house_id)
        # Tin neo HẠNG (0130) không thuộc phòng nào: nó khớp khi phòng server
        # vừa bốc đúng là phòng của hạng đó. Chỉ chấp nhận `source_room_id`
        # như trước là khoá cứng mọi đơn đặt từ tin khách sạn/homestay.
        hop_le = tin is not None and (
            getattr(tin, "source_room_id", None) == room.id
            or (
                getattr(tin, "loai_phong_id", None) is not None
                and tin.loai_phong_id == room.loai_phong_id
            )
        )
        if not hop_le:
            raise HTTPException(
                status_code=422,
                detail="Tin đăng không khớp với phòng đang đặt.",
            )

    data = payload.model_dump()
    data["guest_user_id"] = guest_user_id
    data["sale_id"] = sale_id
    res = reservation_service.create_reservation(
        db,
        host_id=building.host_id,
        payload=data,
        actor_id=guest_user_id,
        source="marketplace",
    )
    db.commit()
    db.refresh(res)
    publish_status_change(
        entity="reservation", entity_id=res.id, from_status=None,
        to_status=res.status, participant_ids=(res.guest_user_id, res.host_id, res.sale_id),
        actor_id=guest_user_id, action="create",
    )
    return _serialise(res, db)


@router.get("", response_model=list[ReservationResponse], response_model_exclude_none=True)
def list_my_reservations(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    rows = (
        db.query(models.Reservation)
        .filter(models.Reservation.guest_user_id == claims["sub"])
        .order_by(models.Reservation.check_in_date.desc())
        .all()
    )
    return [_serialise(r, db) for r in rows]


@router.get("/{reservation_id}/phieu")
def phieu_dat_phong_cua_toi(
    reservation_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Phiếu đặt phòng — màn xác nhận sau khi đặt, mở lại được từ Đã đặt."""
    res = db.get(models.Reservation, reservation_id)
    if (
        res is None
        or not res.booking_mode
        or not phieu_dat_phong.duoc_xem(db, res, claims["sub"], claims.get("role") == "admin")
    ):
        # 404 cho cả "không có" lẫn "không phải của bạn": không để dò id.
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn đặt phòng")
    return phieu_dat_phong.phieu(db, res)


def _don_cua_toi(db: Session, reservation_id: int, uid: int) -> models.Reservation:
    res = db.get(models.Reservation, reservation_id)
    if res is None or res.guest_user_id != uid:
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn đặt phòng")
    return res


@router.get("/{reservation_id}/lich-su")
def lich_su_don(
    reservation_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Dòng thời gian của đơn: ai làm gì lúc nào — khách, sale, chủ phòng đều đọc được."""
    res = db.get(models.Reservation, reservation_id)
    if res is None or not phieu_dat_phong.duoc_xem(
        db, res, claims["sub"], claims.get("role") == "admin"
    ):
        raise HTTPException(status_code=404, detail="Không tìm thấy đơn đặt phòng")
    return lich_su_dat.doc(db, lich_su_dat.DON, res, claims["sub"])


@router.patch("/{reservation_id}")
def sua_don_cua_toi(
    reservation_id: int,
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Khách sửa tên / SĐT / số khách / ghi chú khi đơn còn mở."""
    res = _don_cua_toi(db, reservation_id, claims["sub"])
    sua_dat_cho.sua_don(db, res, claims["sub"], body)
    db.commit()
    db.refresh(res)
    return phieu_dat_phong.phieu(db, res)


def _khung_moi(body: dict) -> tuple[str, datetime, datetime]:
    try:
        return (
            str(body["booking_mode"]),
            datetime.fromisoformat(str(body["check_in_at"]).replace("Z", "+00:00")),
            datetime.fromisoformat(str(body["check_out_at"]).replace("Z", "+00:00")),
        )
    except (KeyError, ValueError) as exc:
        raise HTTPException(422, "Cần hình thức và đủ giờ nhận, trả phòng") from exc


@router.post("/{reservation_id}/doi-gio/bao-gia")
def bao_gia_doi_gio(
    reservation_id: int,
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Báo giá cho giờ mới — xét trùng lịch BỎ QUA chính đơn này."""
    res = _don_cua_toi(db, reservation_id, claims["sub"])
    mode, vao, ra = _khung_moi(body)
    return sua_dat_cho.bao_gia_doi_gio(db, res, mode, vao, ra)


@router.post("/{reservation_id}/doi-gio")
def doi_gio_don(
    reservation_id: int,
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Đổi giờ đơn còn hạn huỷ miễn phí → về chờ sale xác nhận lại."""
    res = _don_cua_toi(db, reservation_id, claims["sub"])
    mode, vao, ra = _khung_moi(body)
    sua_dat_cho.doi_gio_don(
        db, res, claims["sub"], mode, vao, ra, str(body.get("quote_token") or "")
    )
    db.commit()
    db.refresh(res)
    return phieu_dat_phong.phieu(db, res)


@router.post(
    "/{reservation_id}/cancel", response_model=ReservationResponse, response_model_exclude_none=True
)
def cancel_my_reservation(
    reservation_id: int,
    payload: ReservationCancel,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    res = db.get(models.Reservation, reservation_id)
    if res is None or res.guest_user_id != claims["sub"]:
        raise HTTPException(status_code=404, detail="Đơn không tồn tại")
    old_status = res.status
    res = reservation_service.cancel(
        db,
        host_id=res.host_id,
        reservation_id=reservation_id,
        actor_id=claims["sub"],
        reason=payload.reason,
    )
    db.commit()
    db.refresh(res)
    publish_status_change(
        entity="reservation", entity_id=res.id, from_status=old_status,
        to_status=res.status, participant_ids=(res.guest_user_id, res.host_id, res.sale_id),
        actor_id=claims["sub"], action="cancel",
    )
    return _serialise(res, db)
