"""Host dashboard 'cần action' aggregator (Phase 06 — D5).

Per BA §9 D4: no cron job — categories computed on demand at request time.
Each list capped at 10 rows so the dashboard payload stays small.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app import models


# How far ahead "expiring soon" looks (BA D5).
EXPIRING_DAYS = 30
# How many rows per category in the action_items payload.
CATEGORY_LIMIT = 10


def _today_iso() -> str:
    return datetime.utcnow().date().isoformat()


def _expiring_contracts(db: Session, host_id: int) -> list[dict]:
    today = _today_iso()
    cutoff = (datetime.utcnow().date() + timedelta(days=EXPIRING_DAYS)).isoformat()
    rows = (
        db.query(models.Contract)
        .filter(
            models.Contract.host_id == host_id,
            models.Contract.status == "active",
            models.Contract.end_date >= today,
            models.Contract.end_date <= cutoff,
        )
        .order_by(models.Contract.end_date.asc())
        .limit(CATEGORY_LIMIT)
        .all()
    )
    return [
        {
            "contract_id": c.id,
            "room_id": c.room_id,
            "end_date": c.end_date,
            "monthly_rent": c.monthly_rent,
        }
        for c in rows
    ]


def _overdue_invoices(db: Session, host_id: int) -> list[dict]:
    today = _today_iso()
    rows = (
        db.query(models.Invoice)
        .filter(
            models.Invoice.host_id == host_id,
            models.Invoice.status.in_(("sent", "overdue")),
            models.Invoice.due_date < today,
        )
        .order_by(models.Invoice.due_date.asc())
        .limit(CATEGORY_LIMIT)
        .all()
    )
    return [
        {
            "invoice_id": inv.id,
            "invoice_number": inv.invoice_number,
            "contract_id": inv.contract_id,
            "due_date": inv.due_date,
            "total_amount": inv.total_amount,
            "paid_amount": inv.paid_amount,
        }
        for inv in rows
    ]


def _overdue_khai_bao(db: Session, host_id: int) -> list[dict]:
    cutoff = datetime.utcnow() - timedelta(hours=12)
    rows = (
        db.query(models.KhaiBaoTamTru)
        .filter(
            models.KhaiBaoTamTru.host_id == host_id,
            models.KhaiBaoTamTru.declared_at.is_(None),
            models.KhaiBaoTamTru.status != "skipped",
            models.KhaiBaoTamTru.check_in_at < cutoff,
        )
        .order_by(models.KhaiBaoTamTru.check_in_at.asc())
        .limit(CATEGORY_LIMIT)
        .all()
    )
    return [
        {
            "khai_bao_id": k.id,
            "tenant_id": k.tenant_id,
            "contract_id": k.contract_id,
            "check_in_at": k.check_in_at.isoformat(),
        }
        for k in rows
    ]


def _maintenance_rooms(db: Session, host_id: int) -> list[dict]:
    rows = (
        db.query(models.Room, models.Building)
        .join(models.Building, models.Building.id == models.Room.building_id)
        .filter(
            models.Building.host_id == host_id,
            models.Room.status == "maintenance",
        )
        .order_by(models.Building.id, models.Room.code)
        .limit(CATEGORY_LIMIT)
        .all()
    )
    return [
        {
            "room_id": r.id,
            "room_code": r.code,
            "building_id": b.id,
            "building_name": b.name,
            "maintenance_start": r.maintenance_start,
            "maintenance_end": r.maintenance_end,
        }
        for r, b in rows
    ]


def action_items(db: Session, host_id: int) -> dict:
    """Return the 4 'cần action' categories with counts + first 10 rows each."""
    expiring = _expiring_contracts(db, host_id)
    overdue_inv = _overdue_invoices(db, host_id)
    overdue_kbtt = _overdue_khai_bao(db, host_id)
    maintenance = _maintenance_rooms(db, host_id)

    return {
        "expiring_contracts": expiring,
        "overdue_invoices": overdue_inv,
        "overdue_khai_bao": overdue_kbtt,
        "maintenance_rooms": maintenance,
        "summary": {
            "expiring_count": len(expiring),
            "overdue_invoice_count": len(overdue_inv),
            "overdue_khai_bao_count": len(overdue_kbtt),
            "maintenance_count": len(maintenance),
        },
    }


def reminder_target(
    db: Session, host_id: int, invoice_id: int
) -> Optional[dict]:
    """Resolve tenant + amount for an invoice — used by Zalo reminder builder."""
    inv = (
        db.query(models.Invoice)
        .filter(
            models.Invoice.id == invoice_id,
            models.Invoice.host_id == host_id,
        )
        .first()
    )
    if inv is None:
        return None
    contract = db.get(models.Contract, inv.contract_id)
    tenant: Optional[models.Tenant] = None
    if contract is not None:
        pivot = (
            db.query(models.ContractTenant)
            .filter(models.ContractTenant.contract_id == contract.id)
            .first()
        )
        if pivot is not None:
            tenant = db.get(models.Tenant, pivot.tenant_id)
    if tenant is None or not tenant.phone:
        return None
    return {
        "invoice": inv,
        "tenant": tenant,
    }
