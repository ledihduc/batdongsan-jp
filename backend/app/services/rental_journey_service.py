"""Application service for the customer -> sale -> owner rental journey."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import helpers, models
from app.config import settings
from app.services import (
    activity_deposit_policy_service,
    contact_privacy_service,
    contract_service,
    khai_thac_service,
    lich_xem_service,
    marketplace_sync_service,
    rental_journey_policy as policy,
)
from app.status_realtime import publish_status_change

APP_DEPOSIT = "APP_DEPOSIT"
OWNER_DEPOSIT = "OWNER_DEPOSIT"
PAYMENT_KINDS = {APP_DEPOSIT, OWNER_DEPOSIT}


def _actor_role(journey: models.RentalJourney, claims: dict) -> Optional[str]:
    uid = claims["sub"]
    if claims.get("role") == "admin":
        return "admin"
    if journey.customer_id == uid:
        return "customer"
    if journey.sale_id == uid:
        return "sale"
    if journey.owner_id == uid:
        return "owner"
    return None


def _visible(
    db: Session, journey_id: int, claims: dict, *, lock: bool = False
) -> tuple[models.RentalJourney, str]:
    query = db.query(models.RentalJourney).filter(models.RentalJourney.id == journey_id)
    if lock:
        query = query.with_for_update()
    journey = query.first()
    role = _actor_role(journey, claims) if journey is not None else None
    if journey is None or role is None:
        raise HTTPException(404, "Không tìm thấy hồ sơ thuê")
    return journey, role


def _payments(db: Session, journey_id: int) -> dict[str, models.RentalJourneyPayment]:
    return {
        payment.kind: payment
        for payment in db.query(models.RentalJourneyPayment)
        .filter(models.RentalJourneyPayment.journey_id == journey_id)
        .all()
    }


def _has_proof(payment: Optional[models.RentalJourneyPayment]) -> bool:
    return bool(payment and payment.proof_urls and payment.submitted_at)


def _event(
    db: Session,
    journey: models.RentalJourney,
    *,
    actor_id: Optional[int],
    actor_role: str,
    event_type: str,
    from_status: Optional[str] = None,
    payload: Optional[dict] = None,
) -> None:
    db.add(
        models.RentalJourneyEvent(
            journey_id=journey.id,
            actor_id=actor_id,
            actor_role=actor_role,
            event_type=event_type,
            from_status=from_status,
            to_status=journey.status,
            payload=payload,
            created_at=datetime.utcnow(),
        )
    )


def _publish_journey_status(
    journey: models.RentalJourney,
    *,
    from_status: Optional[str],
    actor_id: Optional[int],
    action: str,
) -> None:
    """Publish only after the caller has committed the journey mutation."""
    publish_status_change(
        entity="rental_journey",
        entity_id=journey.id,
        from_status=from_status,
        to_status=journey.status,
        participant_ids=(journey.customer_id, journey.sale_id, journey.owner_id),
        actor_id=actor_id,
        action=action,
    )


def _user_name(
    db: Session, user_id: Optional[int], users: Optional[dict[int, models.User]] = None
) -> Optional[str]:
    user = users.get(user_id) if users is not None and user_id else None
    if user is None and users is None and user_id:
        user = db.get(models.User, user_id)
    return user.name if user else None


def _subject(
    db: Session, journey: models.RentalJourney, context: Optional[dict] = None
) -> dict:
    if journey.room_id:
        room = (
            context["rooms"].get(journey.room_id)
            if context is not None
            else db.get(models.Room, journey.room_id)
        )
        building = (
            context["buildings"].get(room.building_id)
            if context is not None and room
            else db.get(models.Building, room.building_id) if room else None
        )
        return {
            "title": (
                f"Phòng {room.code} · {building.name}"
                if room and building
                else f"Phòng {room.code}" if room else "Phòng đã gỡ"
            ),
            "image": (room.images[0] if room and room.images else None),
            "room_id": journey.room_id,
            "house_id": journey.house_id,
        }
    house = (
        context["houses"].get(journey.house_id)
        if context is not None and journey.house_id
        else db.get(models.House, journey.house_id) if journey.house_id else None
    )
    return {
        "title": house.title if house else "Tin đã gỡ",
        "image": (house.images[0] if house and house.images else None),
        "room_id": None,
        "house_id": journey.house_id,
    }


def serialize(
    db: Session,
    journey: models.RentalJourney,
    claims: dict,
    context: Optional[dict] = None,
) -> dict:
    role = _actor_role(journey, claims)
    if role is None:
        raise HTTPException(404, "Không tìm thấy hồ sơ thuê")
    payments = (
        context["payments"].get(journey.id, {})
        if context is not None
        else _payments(db, journey.id)
    )
    app_payment = payments.get(APP_DEPOSIT)
    owner_payment = payments.get(OWNER_DEPOSIT)
    has_contract = bool(journey.contract_urls)
    has_app_proof = _has_proof(app_payment)
    has_owner_proof = _has_proof(owner_payment)
    platform_bps, owner_bps, deposit_policy_provenance = (
        activity_deposit_policy_service.long_term_split_bps(journey)
    )
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=has_contract,
        has_app_proof=has_app_proof,
        has_owner_proof=has_owner_proof,
        owner_proof_acknowledged=bool(owner_payment and owner_payment.acknowledged_at),
    )
    appointment = (
        context["appointments"].get(journey.appointment_id)
        if context is not None
        else db.get(models.ViewingAppointment, journey.appointment_id)
    )
    users = context["users"] if context is not None else None
    return {
        "id": journey.id,
        "appointment_id": journey.appointment_id,
        "status": journey.status,
        "viewer_role": role,
        "subject": _subject(db, journey, context),
        "participants": {
            "customer": {
                "id": journey.customer_id,
                "name": _user_name(db, journey.customer_id, users),
            },
            "sale": {
                "id": journey.sale_id,
                "name": _user_name(db, journey.sale_id, users),
            } if journey.sale_id else None,
            "owner": {
                "id": journey.owner_id,
                "name": _user_name(db, journey.owner_id, users),
            },
        },
        # Never infer a phone/email from ``participants``.  This is the only
        # journey projection that may contain counterparty contact and the
        # policy is evaluated for the current viewer on every read.
        "contact_access": contact_privacy_service.access_for_journey(db, journey, claims),
        "appointment": {
            "date": appointment.booking_date if appointment else None,
            "time": appointment.booking_time if appointment else None,
            "status": appointment.status if appointment else None,
        },
        "contract": {
            "urls": list(journey.contract_urls or []),
            "note": journey.contract_note,
            "submitted_at": (
                journey.contract_submitted_at.isoformat()
                if journey.contract_submitted_at else None
            ),
        },
        # Hợp đồng THẬT trong sổ của chủ nhà (khác `contract` ở trên — đó chỉ
        # là ảnh chụp giấy tờ sale gửi lên). Có khối này thì app nói được
        # "phòng đã nhận khách" thay vì chỉ "hồ sơ hoàn tất".
        "hop_dong_da_ky": _hop_dong_da_ky(db, journey),
        "total_deposit": journey.total_deposit,
        "deposit_policy": {
            "policy_version": journey.deposit_policy_version,
            "platform_deposit_percent": format(platform_bps / 100, "g"),
            "owner_deposit_percent": format(owner_bps / 100, "g"),
            "provenance": deposit_policy_provenance,
        },
        "payments": [
            {
                "kind": payment.kind,
                "amount": payment.amount,
                "status": payment.status,
                "proof_urls": list(payment.proof_urls or []),
                "submitted_at": (
                    payment.submitted_at.isoformat() if payment.submitted_at else None
                ),
                "acknowledged_at": (
                    payment.acknowledged_at.isoformat()
                    if payment.acknowledged_at else None
                ),
            }
            for payment in sorted(payments.values(), key=lambda item: item.kind)
        ],
        "available_actions": actions,
        "cancel_reason": journey.cancel_reason,
        "created_at": journey.created_at.isoformat(),
        "updated_at": journey.updated_at.isoformat(),
        "completed_at": (
            journey.completed_at.isoformat() if journey.completed_at else None
        ),
    }


def _hop_dong_da_ky(db: Session, journey: models.RentalJourney) -> Optional[dict]:
    """Hợp đồng đã ký của hồ sơ — `None` khi chưa chốt."""
    ma = getattr(journey, "contract_id", None)
    if not ma:
        return None
    hd = db.get(models.Contract, ma)
    if hd is None:
        return None
    phong = db.get(models.Room, hd.room_id) if hd.room_id else None
    return {
        "id": hd.id,
        "trang_thai": hd.status,
        "tu": hd.start_date,
        "den": hd.end_date,
        "gia_thue": float(hd.monthly_rent or 0),
        "tien_coc": float(hd.deposit or 0),
        "phong": phong.code if phong is not None else "",
        # Câu trả lời cho "khách đã vào ở chưa" — đọc từ CHÍNH trạng thái
        # phòng, không suy từ trạng thái hồ sơ.
        "dang_o": bool(phong is not None and phong.status == "occupied"),
    }


def serialize_many(
    db: Session, journeys: list[models.RentalJourney], claims: dict
) -> list[dict]:
    if not journeys:
        return []
    journey_ids = [item.id for item in journeys]
    payment_rows = (
        db.query(models.RentalJourneyPayment)
        .filter(models.RentalJourneyPayment.journey_id.in_(journey_ids))
        .all()
    )
    payments: dict[int, dict[str, models.RentalJourneyPayment]] = {}
    for payment in payment_rows:
        payments.setdefault(payment.journey_id, {})[payment.kind] = payment

    user_ids = {
        user_id
        for item in journeys
        for user_id in (item.customer_id, item.sale_id, item.owner_id)
        if user_id is not None
    }
    users = {
        user.id: user
        for user in db.query(models.User).filter(models.User.id.in_(user_ids)).all()
    }
    appointment_ids = [item.appointment_id for item in journeys]
    appointments = {
        item.id: item
        for item in db.query(models.ViewingAppointment)
        .filter(models.ViewingAppointment.id.in_(appointment_ids))
        .all()
    }
    room_ids = [item.room_id for item in journeys if item.room_id is not None]
    rooms = {
        room.id: room
        for room in db.query(models.Room).filter(models.Room.id.in_(room_ids)).all()
    }
    building_ids = {room.building_id for room in rooms.values()}
    buildings = {
        building.id: building
        for building in db.query(models.Building)
        .filter(models.Building.id.in_(building_ids))
        .all()
    }
    house_ids = [item.house_id for item in journeys if item.house_id is not None]
    houses = {
        house.id: house
        for house in db.query(models.House).filter(models.House.id.in_(house_ids)).all()
    }
    context = {
        "payments": payments,
        "users": users,
        "appointments": appointments,
        "rooms": rooms,
        "buildings": buildings,
        "houses": houses,
    }
    return [serialize(db, item, claims, context) for item in journeys]


def list_for_actor(
    db: Session,
    claims: dict,
    *,
    view: str,
    status: Optional[str],
    page: int,
    page_size: int,
) -> dict:
    uid = claims["sub"]
    query = db.query(models.RentalJourney)
    if claims.get("role") != "admin":
        column = {
            "customer": models.RentalJourney.customer_id,
            "sale": models.RentalJourney.sale_id,
            "owner": models.RentalJourney.owner_id,
        }.get(view)
        if column is None:
            raise HTTPException(422, "Góc nhìn không hợp lệ")
        query = query.filter(column == uid)
    if status:
        if status not in policy.ALL_STATUSES:
            raise HTTPException(422, "Trạng thái không hợp lệ")
        query = query.filter(models.RentalJourney.status == status)
    total = query.count()
    rows = (
        query.order_by(models.RentalJourney.updated_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return {
        "data": serialize_many(db, rows, claims),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total,
            "total_pages": (total + page_size - 1) // page_size,
        },
    }


def create_from_viewing_result(
    db: Session,
    claims: dict,
    *,
    appointment_id: int,
    outcome: str,
    reason: Optional[str],
    allow_confirmed: bool = False,
    event_type: str = "VIEWING_RESULT_RECORDED",
) -> models.RentalJourney:
    appointment = (
        db.query(models.ViewingAppointment)
        .filter(models.ViewingAppointment.id == appointment_id)
        .with_for_update()
        .first()
    )
    if appointment is None or appointment.guest_id != claims["sub"]:
        raise HTTPException(404, "Không tìm thấy lịch xem")
    accepted_statuses = (
        ("approved", "completed", "locked")
        if allow_confirmed
        else ("completed", "locked")
    )
    if appointment.loai != "xem" or appointment.status not in accepted_statuses:
        raise HTTPException(409, "Chỉ ghi kết quả sau khi buổi xem đã hoàn thành")
    existing = (
        db.query(models.RentalJourney)
        .filter(models.RentalJourney.appointment_id == appointment_id)
        .first()
    )
    if existing is not None:
        return existing

    anchor = lich_xem_service.neo_cua(db, appointment)
    if anchor.chu_nha_id is None:
        raise HTTPException(409, "Chưa xác định được chủ nhà")
    if outcome == "INTERESTED" and anchor.sale_id is None:
        raise HTTPException(409, "Phòng chưa được gán sale phụ trách")
    status = (
        policy.CUSTOMER_INTERESTED
        if outcome == "INTERESTED"
        else policy.CUSTOMER_DECLINED
    )
    journey = models.RentalJourney(
        appointment_id=appointment.id,
        room_id=appointment.room_id,
        house_id=appointment.house_id,
        customer_id=appointment.guest_id,
        sale_id=anchor.sale_id,
        owner_id=anchor.chu_nha_id,
        status=status,
        contract_urls=[],
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    activity_deposit_policy_service.apply_long_term_snapshot(db, journey)
    db.add(journey)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        journey = (
            db.query(models.RentalJourney)
            .filter(models.RentalJourney.appointment_id == appointment_id)
            .first()
        )
        if journey is None:
            raise HTTPException(409, "Kết quả buổi xem đã được ghi")
        return journey

    if outcome == "INTERESTED":
        db.add_all(
            [
                models.RentalJourneyPayment(
                    journey_id=journey.id, kind=kind, amount=0, status="PENDING"
                )
                for kind in (APP_DEPOSIT, OWNER_DEPOSIT)
            ]
        )
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role="customer",
        event_type=event_type,
        payload={"outcome": outcome, "reason": (reason or "").strip()[:500]},
    )
    if anchor.sale_id:
        helpers.push_notification(
            db,
            anchor.sale_id,
            "rental_journey_started",
            "Khách muốn thuê phòng" if outcome == "INTERESTED" else "Khách không thuê",
            "Mở hồ sơ để xử lý bước tiếp theo.",
            journey.id,
        )
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey, from_status=None, actor_id=claims["sub"], action=event_type
    )
    return journey


def submit_contract(
    db: Session,
    claims: dict,
    *,
    journey_id: int,
    urls: list[str],
    total_deposit: int,
    note: Optional[str],
) -> models.RentalJourney:
    journey, role = _visible(db, journey_id, claims, lock=True)
    payments = _payments(db, journey.id)
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=bool(journey.contract_urls),
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(payments.get(OWNER_DEPOSIT)),
    )
    if policy.UPLOAD_CONTRACT not in actions:
        raise HTTPException(409, "Không thể gửi hợp đồng ở bước hiện tại")
    if any(_has_proof(payment) for payment in payments.values()) and total_deposit != journey.total_deposit:
        raise HTTPException(409, "Không thể đổi số tiền sau khi khách đã nộp minh chứng")

    old_status = journey.status
    journey.contract_urls = policy.validate_evidence_paths(urls)
    journey.contract_note = (note or "").strip()[:1000] or None
    journey.contract_submitted_by = claims["sub"]
    journey.contract_submitted_at = datetime.utcnow()
    journey.total_deposit = total_deposit
    platform_bps, _owner_bps, _policy_provenance = (
        activity_deposit_policy_service.long_term_split_bps(journey)
    )
    split_app = total_deposit * platform_bps // 10_000
    for kind, amount in (
        (APP_DEPOSIT, split_app),
        (OWNER_DEPOSIT, total_deposit - split_app),
    ):
        payment = payments.get(kind)
        if payment is None:
            payment = models.RentalJourneyPayment(
                journey_id=journey.id, kind=kind, status="PENDING"
            )
            db.add(payment)
            payments[kind] = payment
        payment.amount = amount
    journey.status = policy.status_after_evidence(
        has_contract=True,
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(payments.get(OWNER_DEPOSIT)),
    )
    journey.updated_at = datetime.utcnow()
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=role,
        event_type="CONTRACT_SUBMITTED",
        from_status=old_status,
        payload={"file_count": len(urls), "total_deposit": total_deposit},
    )
    helpers.push_notification(
        db,
        journey.customer_id,
        "rental_contract_ready",
        "Hợp đồng đã sẵn sàng",
        "Kiểm tra hợp đồng và hoàn tất hai phần cọc.",
        journey.id,
    )
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey, from_status=old_status, actor_id=claims["sub"], action="CONTRACT_SUBMITTED"
    )
    return journey


def submit_payment_proof(
    db: Session,
    claims: dict,
    *,
    journey_id: int,
    kind: str,
    urls: list[str],
) -> models.RentalJourney:
    if kind not in PAYMENT_KINDS:
        raise HTTPException(422, "Loại thanh toán không hợp lệ")
    journey, role = _visible(db, journey_id, claims, lock=True)
    payments = _payments(db, journey.id)
    action = (
        policy.SUBMIT_APP_DEPOSIT if kind == APP_DEPOSIT else policy.SUBMIT_OWNER_DEPOSIT
    )
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=bool(journey.contract_urls),
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(payments.get(OWNER_DEPOSIT)),
    )
    if action not in actions:
        raise HTTPException(409, "Không thể nộp minh chứng ở bước hiện tại")
    payment = payments.get(kind)
    if payment is None:
        raise HTTPException(409, "Hợp đồng chưa thiết lập khoản cọc này")
    old_status = journey.status
    payment.proof_urls = policy.validate_evidence_paths(urls)
    payment.submitted_by = claims["sub"]
    payment.submitted_at = datetime.utcnow()
    payment.status = "SUBMITTED"
    journey.status = policy.status_after_evidence(
        has_contract=bool(journey.contract_urls),
        has_app_proof=(kind == APP_DEPOSIT) or _has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=(kind == OWNER_DEPOSIT) or _has_proof(payments.get(OWNER_DEPOSIT)),
    )
    journey.updated_at = datetime.utcnow()
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=role,
        event_type="PAYMENT_PROOF_SUBMITTED",
        from_status=old_status,
        payload={"kind": kind, "file_count": len(urls)},
    )
    if role == "sale":
        # Sale nộp hộ: báo KHÁCH (tiền của khách, ảnh của khách) và chủ nhà
        # nếu là khoản của chủ nhà — ai đủ giấy thì bấm chốt được ngay.
        nhan = {journey.customer_id}
        if kind == OWNER_DEPOSIT:
            nhan.add(journey.owner_id)
        tieu_de = "Sale đã gửi minh chứng cọc giúp bạn"
    else:
        nhan = {journey.owner_id if kind == OWNER_DEPOSIT else journey.sale_id}
        tieu_de = "Khách đã gửi minh chứng cọc"
    for notify_user in nhan:
        if notify_user:
            helpers.push_notification(
                db,
                notify_user,
                "rental_payment_proof",
                tieu_de,
                "Mở hồ sơ thuê để kiểm tra.",
                journey.id,
            )
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey,
        from_status=old_status,
        actor_id=claims["sub"],
        action="PAYMENT_PROOF_SUBMITTED",
    )
    return journey


def acknowledge_owner_deposit(
    db: Session, claims: dict, *, journey_id: int
) -> models.RentalJourney:
    journey = acknowledge_owner_deposit_staged(db, claims, journey_id=journey_id)
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey,
        from_status=journey.status,
        actor_id=claims["sub"],
        action="OWNER_DEPOSIT_ACKNOWLEDGED",
    )
    return journey


def acknowledge_owner_deposit_staged(
    db: Session, claims: dict, *, journey_id: int
) -> models.RentalJourney:
    """Như `acknowledge_owner_deposit` nhưng KHÔNG commit/publish — để backoffice
    ghi nhật ký quản trị trong cùng transaction rồi tự publish sau commit."""
    journey, role = _visible(db, journey_id, claims, lock=True)
    payments = _payments(db, journey.id)
    owner_payment = payments.get(OWNER_DEPOSIT)
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=bool(journey.contract_urls),
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(owner_payment),
        owner_proof_acknowledged=bool(owner_payment and owner_payment.acknowledged_at),
    )
    if policy.ACKNOWLEDGE_OWNER_DEPOSIT not in actions or owner_payment is None:
        raise HTTPException(409, "Khoản cọc chủ nhà chưa thể xác nhận")
    owner_payment.status = "ACKNOWLEDGED"
    owner_payment.acknowledged_by = claims["sub"]
    owner_payment.acknowledged_at = datetime.utcnow()
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=role,
        event_type="OWNER_DEPOSIT_ACKNOWLEDGED",
        payload={"kind": OWNER_DEPOSIT},
    )
    return journey


def _confirm_deal(db: Session, journey: models.RentalJourney, actor_id: int) -> None:
    target = (
        models.Deal.room_id == journey.room_id
        if journey.room_id is not None
        else models.Deal.house_id == journey.house_id
    )
    deal = (
        db.query(models.Deal)
        .filter(target, models.Deal.customer_id == journey.customer_id)
        .order_by(models.Deal.id.desc())
        .first()
    )
    if deal is None:
        room = db.get(models.Room, journey.room_id) if journey.room_id else None
        house = db.get(models.House, journey.house_id) if journey.house_id else None
        deal = models.Deal(
            room_id=journey.room_id,
            house_id=journey.house_id,
            owner_id=journey.owner_id,
            sale_id=journey.sale_id,
            customer_id=journey.customer_id,
            deal_type="rent",
            amount=int(room.base_price if room else house.price if house else 0),
            status="confirmed",
            note=f"Chốt từ hồ sơ thuê #{journey.id}",
            created_at=datetime.utcnow(),
        )
        db.add(deal)
    deal.status = "confirmed"
    deal.sale_id = journey.sale_id
    deal.confirmed_at = datetime.utcnow()
    deal.confirmed_by = actor_id


def confirm_rental(
    db: Session, claims: dict, *, journey_id: int
) -> models.RentalJourney:
    """Chốt thuê — KHÁCH hoặc CHỦ NHÀ, ai bấm trước cũng xong (23/09/2026).

    Hai việc gộp làm một, vì tách ra là để khách nửa đường:

    1. Ghi hợp đồng từ buổi xem (như trước);
    2. **KÍCH HOẠT** hợp đồng ngay: phòng sang "đang thuê", kênh dài hạn/mặt
       bằng chốt lại thành ĐÃ CHO THUÊ, và ghi chiếm dụng trên dòng thời gian
       chung của phòng.

    Trước đây bước 2 không có: hợp đồng nằm ở `draft`, `rooms.status` vẫn
    `vacant`, kênh chỉ về GIỮ CHỖ. Nhìn từ app thì hồ sơ "hoàn tất" nhưng Trang
    chủ và Sổ phòng vẫn báo phòng trống, khách không hiện ở "Khách thuê", và
    nút duy nhất kích hoạt được hợp đồng nằm ở màn quản lý hợp đồng cũ mà
    không đường dẫn nào trong luồng chốt thuê trỏ tới.
    """
    journey, role = _visible(db, journey_id, claims, lock=True)
    payments = _payments(db, journey.id)
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=bool(journey.contract_urls),
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(payments.get(OWNER_DEPOSIT)),
    )
    if policy.CONFIRM_RENTAL not in actions:
        raise HTTPException(409, "Không thể chốt thuê ở bước hiện tại")
    old_status = journey.status
    contract, _tenant, _placeholder = (
        marketplace_sync_service.create_contract_from_appointment(
            db,
            host_id=journey.owner_id,
            appointment_id=journey.appointment_id,
            actor_id=claims["sub"],
        )
    )
    appointment = db.get(models.ViewingAppointment, journey.appointment_id)
    if appointment:
        appointment.status = "locked"
    db.flush()
    # Nhận khách vào ở: draft → active (phòng occupied, kênh ĐÃ CHO THUÊ, ghi
    # chiếm dụng). `host_id` là CHỦ TOÀ chứ không phải người bấm — sale hay
    # khách bấm thì hợp đồng vẫn là của chủ nhà.
    if contract.status == "draft":
        contract_service.activate_contract(
            db, contract_id=contract.id, host_id=journey.owner_id
        )
    journey.contract_id = contract.id
    _confirm_deal(db, journey, claims["sub"])
    journey.status = policy.COMPLETED
    journey.completed_at = datetime.utcnow()
    journey.updated_at = datetime.utcnow()
    nguoi_chot = "owner" if role in {"owner", "admin"} else "customer"
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=nguoi_chot,
        event_type=(
            "RENTAL_CONFIRMED_BY_OWNER"
            if nguoi_chot == "owner"
            else "RENTAL_CONFIRMED_BY_CUSTOMER"
        ),
        from_status=old_status,
    )
    ai = "Chủ nhà" if nguoi_chot == "owner" else "Khách"
    # Báo cho HAI người còn lại, không báo cho chính người vừa bấm.
    for user_id in {journey.sale_id, journey.owner_id, journey.customer_id}:
        if user_id and user_id != claims["sub"]:
            helpers.push_notification(
                db,
                user_id,
                "rental_completed",
                f"{ai} đã xác nhận thuê",
                "Hợp đồng đã hiệu lực, phòng chuyển sang trạng thái đang thuê.",
                journey.id,
            )
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey, from_status=old_status, actor_id=claims["sub"], action="RENTAL_CONFIRMED"
    )
    return journey


#: Tên cũ — giữ cho chỗ gọi ngoài luồng chưa đổi.
confirm_by_customer = confirm_rental


def cancel(
    db: Session, claims: dict, *, journey_id: int, reason: str
) -> models.RentalJourney:
    journey, old_status = cancel_staged(db, claims, journey_id=journey_id, reason=reason)
    db.commit()
    db.refresh(journey)
    _publish_journey_status(
        journey, from_status=old_status, actor_id=claims["sub"], action="JOURNEY_CANCELLED"
    )
    return journey


def cancel_staged(
    db: Session, claims: dict, *, journey_id: int, reason: str
) -> tuple[models.RentalJourney, str]:
    """Như `cancel` nhưng KHÔNG commit/publish. Trả (hồ sơ, trạng thái cũ)."""
    journey, role = _visible(db, journey_id, claims, lock=True)
    payments = _payments(db, journey.id)
    actions = policy.available_actions(
        actor=role,
        status=journey.status,
        has_contract=bool(journey.contract_urls),
        has_app_proof=_has_proof(payments.get(APP_DEPOSIT)),
        has_owner_proof=_has_proof(payments.get(OWNER_DEPOSIT)),
    )
    if policy.CANCEL_JOURNEY not in actions:
        raise HTTPException(409, "Không thể huỷ hồ sơ ở bước hiện tại")
    old_status = journey.status
    journey.status = policy.CANCELLED
    journey.cancel_reason = reason.strip()[:500]
    journey.cancelled_at = datetime.utcnow()
    journey.updated_at = datetime.utcnow()
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=role,
        event_type="JOURNEY_CANCELLED",
        from_status=old_status,
        payload={"reason": journey.cancel_reason},
    )
    return journey, old_status


def report(
    db: Session,
    claims: dict,
    *,
    journey_id: int,
    reported_user_id: int,
    reason_code: str,
    detail: str,
    evidence_urls: list[str],
) -> models.RentalJourneyReport:
    journey, role = _visible(db, journey_id, claims, lock=True)
    participants = {journey.customer_id, journey.sale_id, journey.owner_id}
    if reported_user_id == claims["sub"] or reported_user_id not in participants:
        raise HTTPException(422, "Người bị báo cáo không thuộc hồ sơ này")
    report_row = models.RentalJourneyReport(
        journey_id=journey.id,
        reporter_id=claims["sub"],
        reported_user_id=reported_user_id,
        reason_code=reason_code,
        detail=detail.strip()[:1000],
        evidence_urls=evidence_urls,
        status="PENDING",
        created_at=datetime.utcnow(),
    )
    db.add(report_row)
    old_status = journey.status
    if journey.status != policy.COMPLETED:
        journey.status = policy.DISPUTED
        journey.updated_at = datetime.utcnow()
    _event(
        db,
        journey,
        actor_id=claims["sub"],
        actor_role=role,
        event_type="PARTICIPANT_REPORTED",
        from_status=old_status,
        payload={"reported_user_id": reported_user_id, "reason_code": reason_code},
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, "Bạn đã gửi báo cáo này rồi")
    db.refresh(report_row)
    return report_row


#: Kết luận của nền tảng về một báo cáo. Chỉ chạm `rental_journey_reports.status`
#: — KHÔNG đưa hồ sơ ra khỏi DISPUTED: policy chưa có chuyển trạng thái nào rời
#: DISPUTED, và đoán "quay về bước nào" là quyết định nghiệp vụ chưa được chốt.
REPORT_PENDING = "PENDING"
REPORT_DECISIONS = {"valid": "VALID", "invalid": "INVALID"}


def decide_report_staged(
    db: Session, *, report_id: int, decision: str, actor_id: int
) -> models.RentalJourneyReport:
    """Admin kết luận báo cáo (đúng/không đúng). Không commit — người gọi commit."""
    status = REPORT_DECISIONS.get(decision)
    if status is None:
        raise HTTPException(422, "Kết luận không hợp lệ")
    row = (
        db.query(models.RentalJourneyReport)
        .filter(models.RentalJourneyReport.id == report_id)
        .with_for_update()
        .first()
    )
    if row is None:
        raise HTTPException(404, "Không tìm thấy báo cáo")
    if row.status != REPORT_PENDING:
        raise HTTPException(409, "Báo cáo đã có kết luận")
    journey = db.get(models.RentalJourney, row.journey_id)
    row.status = status
    if journey is not None:
        _event(
            db,
            journey,
            actor_id=actor_id,
            actor_role="admin",
            event_type="REPORT_DECIDED",
            from_status=journey.status,
            # Không chép lý do nội bộ: sự kiện hồ sơ hiện cho cả ba bên tham gia.
            payload={"report_id": row.id, "decision": status},
        )
    return row


#: Tên công khai — backoffice publish SAU khi tự commit lệnh của mình.
publish_journey_status = _publish_journey_status


def events(db: Session, claims: dict, *, journey_id: int) -> list[dict]:
    journey, _role = _visible(db, journey_id, claims)
    rows = (
        db.query(models.RentalJourneyEvent)
        .filter(models.RentalJourneyEvent.journey_id == journey.id)
        .order_by(models.RentalJourneyEvent.created_at.asc(), models.RentalJourneyEvent.id.asc())
        .all()
    )
    return [
        {
            "id": row.id,
            "event_type": row.event_type,
            "actor_role": row.actor_role,
            "actor_name": _user_name(db, row.actor_id),
            "from_status": row.from_status,
            "to_status": row.to_status,
            "payload": row.payload or {},
            "created_at": row.created_at.isoformat(),
        }
        for row in rows
    ]


def payment_account() -> dict:
    configured = bool(
        settings.platform_bank_name
        and settings.platform_bank_account_number
        and settings.platform_bank_account_holder
    )
    return {
        "is_configured": configured,
        "bank_name": settings.platform_bank_name if configured else None,
        "account_number": (
            settings.platform_bank_account_number if configured else None
        ),
        "account_holder": (
            settings.platform_bank_account_holder if configured else None
        ),
        "transfer_prefix": settings.platform_bank_transfer_prefix,
    }


def get_visible(
    db: Session, journey_id: int, claims: dict
) -> models.RentalJourney:
    journey, _role = _visible(db, journey_id, claims)
    return journey
