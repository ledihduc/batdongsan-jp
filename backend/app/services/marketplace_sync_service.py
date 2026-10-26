"""Phase 08 — Marketplace ↔ Ops 1-way sync.

Direction: ops Room → marketplace House (NEVER reverse).
Idempotent: 2x publish on same Room → 1 House row (UPDATE).

Sync rules:
- House.title = "{building.name} - {room.code}" unless host overrode it.
- House.price = Room.base_price.
- House.images = Room.images.
- House.product_type from caller override OR derived (homestay if Room.is_homestay else boarding_house).
- House.status defaults to 'pending' on create (admin approve), 'hidden' on unpublish.
- We DO NOT overwrite House description/address/city/district on re-sync —
  host may have manually edited those marketplace-side.

AC-51 ENFORCEMENT:
  Payout destination on a marketplace House record (House.host_id) is immutable
  once set and must always equal the owner's user ID.  An operator acting via
  delegation MUST NOT be able to alter host_id, bank_account_target, or any
  equivalent payout-routing field.  See assert_payout_target_unchanged and
  assert_payout_fields_absent_from_payload below.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Any, Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.room_repository import RoomRepository

if TYPE_CHECKING:
    from app.services.actor_context import ActorContext


# ---------------------------------------------------------------------------
# AC-51 sentinel error type
# ---------------------------------------------------------------------------


class MarketplacePayoutImmutableError(HTTPException):
    """Raised when an operator-initiated update would change a payout field.

    AC-51: host_id / bank_account_target / payout routing fields are immutable
    for delegation-initiated requests.  Inherits HTTPException so FastAPI
    converts it to a 403 response automatically.
    """

    def __init__(self, field_name: str) -> None:
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "AC51_PAYOUT_IMMUTABLE",
                "message": (
                    f"Operator cannot modify payout field '{field_name}'. "
                    "Only the owner can change payout routing (AC-51)."
                ),
                "field": field_name,
            },
        )


def _now() -> datetime:
    return datetime.utcnow()


def _derive_product_type(room: models.Room, override: Optional[str] = None) -> str:
    if override in {"boarding_house", "homestay", "apartment"}:
        return override
    return "homestay" if room.is_homestay else "boarding_house"


# ---------------------------------------------------------------------------
# AC-51 guard helpers
# ---------------------------------------------------------------------------

# Fields whose values directly control where marketplace payouts are routed.
# Expand this tuple if the schema ever adds payout-routing fields.
_PAYOUT_FIELDS: tuple[str, ...] = (
    "host_id",
    "bank_account_target",
    "bank_account_id",
    "payout_account",
)


def assert_payout_target_unchanged(
    existing_record: Any,
    incoming_payload: Any,
    actor_ctx: "ActorContext",
) -> None:
    """AC-51: raise MarketplacePayoutImmutableError if an operator-initiated
    update would alter any payout-routing field on an existing record.

    This is a defence-in-depth guard called by service functions before
    persisting updates.  The router layer enforces the same invariant via
    assert_payout_fields_absent_from_payload; this service-layer guard catches
    any path that bypasses the router (e.g., internal service-to-service calls).

    Args:
        existing_record: ORM model instance representing the current DB state.
        incoming_payload: Pydantic model or dict with the proposed new values.
        actor_ctx: The ActorContext for the current request.

    Raises:
        MarketplacePayoutImmutableError: if actor is acting via delegation AND
            an incoming payload field would change a payout-routing attribute.
    """
    if not actor_ctx.is_acting_on_behalf:
        # Owner self-acting — allowed to change any field (they own the payout). # AC-51
        return

    # Operator-initiated path — check every known payout field.  # AC-51
    payload_dict: dict[str, Any] = (
        incoming_payload
        if isinstance(incoming_payload, dict)
        else (
            incoming_payload.model_dump(exclude_unset=True)
            if hasattr(incoming_payload, "model_dump")
            else vars(incoming_payload)
        )
    )

    for field_name in _PAYOUT_FIELDS:
        if field_name not in payload_dict:
            continue  # field not being set — safe to skip
        new_value = payload_dict[field_name]
        existing_value = getattr(existing_record, field_name, None)
        if new_value != existing_value:
            raise MarketplacePayoutImmutableError(field_name)  # AC-51


def assert_payout_fields_absent_from_payload(
    payload: Any,
    actor_ctx: "ActorContext",
) -> None:
    """AC-51: raise 403 AC51_PAYOUT_IMMUTABLE if an operator's payload contains
    any payout-routing field set to a value different from the owner's identity.

    Used at the router boundary as an early-exit guard.  When the current schema
    (PublishRoomRequest) has no payout fields, this is a no-op — but documents
    the invariant so future schema additions cannot silently break AC-51.

    Args:
        payload: Pydantic model (the request body).
        actor_ctx: The ActorContext for the current request.

    Raises:
        MarketplacePayoutImmutableError: if operator payload carries a payout field. # AC-51
    """
    if not actor_ctx.is_acting_on_behalf:
        return  # owner-acting: no restriction  # AC-51

    # Operator path — check payload for payout fields.  # AC-51
    payload_dict: dict[str, Any] = (
        payload.model_dump(exclude_unset=True)
        if hasattr(payload, "model_dump")
        else (payload if isinstance(payload, dict) else {})
    )

    for field_name in _PAYOUT_FIELDS:
        if field_name in payload_dict:
            # Any explicit payout field in operator payload is forbidden.
            raise MarketplacePayoutImmutableError(field_name)  # AC-51


def sync_room_to_house(
    db: Session,
    host_id: int,
    room_id: int,
    actor_id: int,
    title: Optional[str] = None,
    description: Optional[str] = None,
    price_override: Optional[float] = None,
    product_type: Optional[str] = None,
) -> tuple[models.House, bool]:
    """Upsert House for the given ops Room. Returns (house, created_bool)."""
    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")
    building = db.get(models.Building, room.building_id)
    if building is None:
        raise HTTPException(status_code=404, detail="Toà nhà không tồn tại")

    default_title = f"{building.name} - {room.code}"
    final_title = title or default_title
    final_price = price_override if price_override is not None else room.base_price
    final_type = _derive_product_type(room, product_type)

    house = (
        db.query(models.House)
        .filter(models.House.source_room_id == room.id)
        .first()
    )
    created = False
    if house is None:
        created = True
        house = models.House(
            host_id=host_id,
            title=final_title,
            description=description or "",
            category_id=0,  # default; admin can re-classify
            price=final_price,
            address=building.address or "",
            city=building.city or "",
            district=building.district or "",
            status="pending",  # admin approval pending
            images=list(room.images) if room.images else [],
            amenities=[],
            listing_type="single",
            total_units=1,
            available_units=1,
            gender_pref="any",
            product_type=final_type,
            source_room_id=room.id,
            last_synced_at=_now(),
        )
        db.add(house)
        db.flush()
    else:
        # Update only synced fields; preserve host's manual edits to other fields.
        house.title = final_title
        house.price = final_price
        house.images = list(room.images) if room.images else []
        house.product_type = final_type
        if description is not None:
            house.description = description
        # If host previously unpublished, re-publishing returns to 'pending'.
        if house.status == "hidden":
            house.status = "pending"
        house.last_synced_at = _now()

    room.is_listed_on_marketplace = True
    room.marketplace_house_id = house.id

    write_change_log(
        db,
        explicit_actor_id=actor_id,
        entity_type="marketplace_sync",
        entity_id=house.id,
        action="create" if created else "update",
        after={
            "room_id": room.id,
            "house_id": house.id,
            "product_type": final_type,
            "price": final_price,
        },
    )
    return house, created


def unpublish_room(
    db: Session, host_id: int, room_id: int, actor_id: int
) -> models.House:
    """Hide marketplace listing without deleting it. Idempotent."""
    room_repo = RoomRepository(db, host_id)
    room = room_repo.get(room_id)
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng không tồn tại")

    house = (
        db.query(models.House)
        .filter(models.House.source_room_id == room.id)
        .first()
    )
    if house is None:
        raise HTTPException(
            status_code=404, detail="Phòng này chưa được đăng lên marketplace"
        )

    house.status = "hidden"
    room.is_listed_on_marketplace = False

    write_change_log(
        db,
        explicit_actor_id=actor_id,
        entity_type="marketplace_sync",
        entity_id=house.id,
        action="unpublish",
        after={"room_id": room.id, "house_id": house.id},
    )
    return house


def list_sync_status(db: Session, host_id: int) -> list[dict]:
    """Return per-room sync status (listed flag + house meta + out-of-sync indicator)."""
    room_repo = RoomRepository(db, host_id)
    rooms = room_repo.list()

    house_ids = [
        r.marketplace_house_id for r in rooms if r.marketplace_house_id is not None
    ]
    houses = {}
    if house_ids:
        for h in (
            db.query(models.House).filter(models.House.id.in_(house_ids)).all()
        ):
            houses[h.id] = h

    buildings = {b.id: b for b in db.query(models.Building).filter(
        models.Building.host_id == host_id
    ).all()}

    out: list[dict] = []
    for room in rooms:
        b = buildings.get(room.building_id)
        house = houses.get(room.marketplace_house_id) if room.marketplace_house_id else None
        out_of_sync = bool(
            house is not None and abs(house.price - room.base_price) > 0.001
        )
        out.append({
            "room_id": room.id,
            "room_code": room.code,
            "building_id": room.building_id,
            "building_name": b.name if b else "",
            "is_listed": room.is_listed_on_marketplace,
            "house_id": house.id if house else None,
            "house_status": house.status if house else None,
            "last_synced_at": house.last_synced_at if house else None,
            "out_of_sync": out_of_sync,
        })
    return out


# ── Booking → draft Contract / Reservation ───────────────────────────────


def _upsert_placeholder_tenant(
    db: Session,
    host_id: int,
    *,
    full_name: str,
    phone: str,
    email: Optional[str],
    booking_type: str,
    booking_id: int,
) -> tuple[models.Tenant, bool]:
    """Return (tenant, is_new). Reuse existing Tenant by (host_id, phone) if found."""
    if phone:
        existing = (
            db.query(models.Tenant)
            .filter(models.Tenant.host_id == host_id, models.Tenant.phone == phone)
            .first()
        )
        if existing is not None:
            return existing, False

    tenant = models.Tenant(
        host_id=host_id,
        full_name=full_name or "Khách marketplace",
        phone=phone or "",
        email=email,
        is_placeholder=True,
        created_from_booking_type=booking_type,
        created_from_booking_id=booking_id,
    )
    db.add(tenant)
    db.flush()
    return tenant, True


def tien_coc_hop_dong(monthly_rent: float, dat_coc) -> float:
    """Tiền cọc của hợp đồng sinh khi chốt thuê.

    `room_kenh.dat_coc` được khai là "số tháng", nhưng app chủ nhà thực tế lưu
    SỐ TIỀN cọc (VND). Nhân thẳng với tiền thuê từng sinh hợp đồng cọc
    4.500.000 × 4.500.000 = 20.250 tỷ ₫. Không có hợp đồng nào cọc quá 24
    tháng, nên giá trị > 24 được hiểu là số tiền tuyệt đối.
    """
    if dat_coc is None:
        return monthly_rent
    v = float(dat_coc)
    if v <= 0:
        return 0.0
    return v if v > 24 else monthly_rent * v


def create_contract_from_appointment(
    db: Session, host_id: int, appointment_id: int, actor_id: int
) -> tuple[models.Contract, models.Tenant, bool]:
    """Approve viewing appointment + create draft Contract (source=marketplace).

    Returns (contract, primary_tenant, placeholder_flag).
    Caller commits.
    """
    appt = db.get(models.ViewingAppointment, appointment_id)
    if appt is None:
        raise HTTPException(status_code=404, detail="Yêu cầu xem nhà không tồn tại")

    house = db.get(models.House, appt.house_id) if appt.house_id else None
    room_id = appt.room_id or (house.source_room_id if house else None)
    room = db.get(models.Room, room_id) if room_id else None
    if room is None:
        raise HTTPException(status_code=404, detail="Phòng nguồn không tồn tại")
    building = db.get(models.Building, room.building_id)
    if building is None or building.host_id != host_id:
        raise HTTPException(status_code=403, detail="Không có quyền với yêu cầu này")
    if room.status != "vacant":
        raise HTTPException(
            status_code=409,
            detail=f"Phòng đang ở trạng thái {room.status} — không tạo HĐ nháp được",
        )

    guest = db.get(models.User, appt.guest_id)
    if guest is None:
        raise HTTPException(status_code=404, detail="Khách không tồn tại")

    existing = (
        db.query(models.Contract)
        .join(models.ContractTenant, models.ContractTenant.contract_id == models.Contract.id)
        .join(models.Tenant, models.Tenant.id == models.ContractTenant.tenant_id)
        .filter(
            models.Contract.room_id == room.id,
            models.Contract.status.in_(("draft", "active")),
            models.Tenant.created_from_booking_type == "viewing_appointment",
            models.Tenant.created_from_booking_id == appt.id,
        )
        .first()
    )
    if existing is not None:
        tenant = db.query(models.Tenant).join(
            models.ContractTenant,
            models.ContractTenant.tenant_id == models.Tenant.id,
        ).filter(models.ContractTenant.contract_id == existing.id).first()
        return existing, tenant, bool(tenant and tenant.is_placeholder)

    tenant, _is_new = _upsert_placeholder_tenant(
        db,
        host_id=host_id,
        full_name=guest.name,
        phone=guest.phone or "",
        email=guest.email,
        booking_type="viewing_appointment",
        booking_id=appt.id,
    )
    placeholder = tenant.is_placeholder

    today_date = datetime.utcnow().date()
    today = today_date.isoformat()
    kenh = db.query(models.RoomKenh).filter(
        models.RoomKenh.room_id == room.id,
        models.RoomKenh.kenh == models.RoomKenh.DAI_HAN,
    ).first()
    monthly_rent = float(kenh.gia if kenh and kenh.gia else room.base_price or 0)
    deposit = tien_coc_hop_dong(monthly_rent, kenh.dat_coc if kenh else None)
    # Phase 04: dual-write FK source_id (marketplace-driven contract).
    from app.services import source_service
    source_id = source_service.resolve_default_source_id(db, host_id, "marketplace")
    contract = models.Contract(
        host_id=host_id,
        room_id=room.id,
        start_date=today,
        end_date=(today_date + timedelta(days=365)).isoformat(),
        monthly_rent=monthly_rent,
        deposit=deposit,
        status="draft",
        source="marketplace",
        source_id=source_id,
        ngay_thanh_toan=today_date.day,
    )
    db.add(contract)
    db.flush()

    db.add(
        models.ContractTenant(
            contract_id=contract.id,
            tenant_id=tenant.id,
            is_primary=True,
            joined_at=today,
        )
    )

    if appt.status == "pending":
        appt.status = "approved"

    write_change_log(
        db,
        explicit_actor_id=actor_id,
        entity_type="contract",
        entity_id=contract.id,
        action="create_from_appointment",
        after={
            "appointment_id": appt.id,
            "room_id": room.id,
            "tenant_id": tenant.id,
            "placeholder": placeholder,
            "source": "marketplace",
        },
    )
    return contract, tenant, placeholder


def approve_reservation_from_booking(
    db: Session, host_id: int, reservation_id: int, actor_id: int
) -> models.Reservation:
    """Approve a marketplace-sourced pending Reservation.

    Thin wrapper around reservation_service.approve() that enforces source check.
    """
    from app.services import reservation_service

    res = db.get(models.Reservation, reservation_id)
    if res is None or res.host_id != host_id:
        raise HTTPException(status_code=404, detail="Đặt phòng không tồn tại")
    if res.source != "marketplace":
        raise HTTPException(
            status_code=400,
            detail=f"Đặt phòng không từ marketplace (nguồn: {res.source})",
        )
    return reservation_service.approve(db, host_id, reservation_id, actor_id)
