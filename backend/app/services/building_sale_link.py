"""Building-scoped sale assignments, shared by linking and claim.

Callers lock the building before changing its link, then commit the link and
assignments together. Legacy links without a building never grant access.
"""

from contextlib import contextmanager
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import models


@contextmanager
def link_transaction(db: Session):
    """Roll back the whole assignment on conflicts, including autoflush errors.

    Building locks serialize normal writers; the unique index is the final
    guard against concurrent/legacy writers. Unrelated integrity errors remain
    visible instead of being misreported as assignment conflicts.
    """
    try:
        yield
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", None)
        if constraint == "uq_sale_owner_links_building_active" or (
            "UNIQUE constraint failed: sale_owner_links.building_id" == str(exc.orig)
        ):
            raise HTTPException(
                status_code=409,
                detail="Liên kết sale của toà nhà vừa thay đổi. Vui lòng tải lại.",
            ) from exc
        raise


def lock_building(db: Session, building_id: int) -> models.Building:
    building = (
        db.query(models.Building)
        .filter(models.Building.id == building_id)
        .populate_existing()
        .with_for_update()
        .first()
    )
    if building is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy toà nhà")
    return building


def active_link(db: Session, building_id: int):
    return (
        db.query(models.SaleOwnerLink)
        .filter(
            models.SaleOwnerLink.building_id == building_id,
            models.SaleOwnerLink.status == "active",
        )
        .first()
    )


def assign_sale(db: Session, building: models.Building, sale_id: int | None):
    building.sale_id = sale_id
    building.updated_at = datetime.utcnow()
    db.query(models.Room).filter(models.Room.building_id == building.id).update(
        {"managed_by_sale_id": sale_id, "updated_at": building.updated_at},
        synchronize_session="fetch",
    )


def has_active_business(db: Session, building_id: int) -> bool:
    contracts = (
        db.query(models.Contract.id)
        .join(models.Room, models.Contract.room_id == models.Room.id)
        .filter(models.Room.building_id == building_id)
    )
    if contracts.filter(models.Contract.status.in_(("draft", "active"))).first():
        return True
    return (
        db.query(models.Invoice.id)
        .join(models.Contract, models.Invoice.contract_id == models.Contract.id)
        .join(models.Room, models.Contract.room_id == models.Room.id)
        .filter(
            models.Room.building_id == building_id,
            models.Invoice.status.in_(("draft", "sent", "issued", "partially_paid", "overdue")),
        )
        .first()
        is not None
    )
