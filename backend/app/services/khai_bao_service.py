"""Khai báo tạm trú service — auto-create + status computation + mark workflows.

Status authority:
    - Persisted `status` column is a hint (for SQL filter perf).
    - `compute_status_now(record)` is the source of truth at read time.
    - When a record is READ via host endpoints, we recompute + persist if drifted.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.khai_bao_repository import KhaiBaoRepository

# 12h deadline per VN law (Nghị định 144/2021 — 12h for urban, 24h for remote).
# Apply uniform 12h for MVP — conservative; host sees overdue badge sooner.
DEADLINE_HOURS = 12

# Public-link expiry — 30d after check-in keeps window tight enough for compliance.
PUBLIC_TOKEN_VALID_DAYS = 30


def _parse_iso_date(iso_date: str) -> datetime:
    """Parse 'YYYY-MM-DD' contract.start_date into datetime at 00:00:00 UTC."""
    return datetime.fromisoformat(str(iso_date))


def compute_status_now(
    record: models.KhaiBaoTamTru,
    now: Optional[datetime] = None,
) -> str:
    """Return live status — overrides persisted column.

    - declared if declared_at is set
    - skipped is sticky (host explicitly opted out)
    - else: pending until check_in + 12h, then overdue
    """
    if record.status == "skipped":
        return "skipped"
    if record.declared_at is not None:
        return "declared"
    now = now or datetime.utcnow()
    deadline = record.check_in_at + timedelta(hours=DEADLINE_HOURS)
    return "overdue" if now >= deadline else "pending"


def deadline_seconds_remaining(
    record: models.KhaiBaoTamTru,
    now: Optional[datetime] = None,
) -> int:
    """Seconds until 12h deadline (negative = past deadline)."""
    now = now or datetime.utcnow()
    deadline = record.check_in_at + timedelta(hours=DEADLINE_HOURS)
    return int((deadline - now).total_seconds())


def auto_create_for_contract(
    db: Session,
    contract: models.Contract,
) -> list[models.KhaiBaoTamTru]:
    """For every tenant on the contract, create a KhaiBaoTamTru row.

    Idempotent: skip pairs that already have a record. Returns the rows
    actually created (may be empty on re-trigger).
    Caller commits.
    """
    pivots = (
        db.query(models.ContractTenant)
        .filter(models.ContractTenant.contract_id == contract.id)
        .all()
    )
    if not pivots:
        return []

    check_in = _parse_iso_date(contract.start_date)
    expires = check_in + timedelta(days=PUBLIC_TOKEN_VALID_DAYS)
    repo = KhaiBaoRepository(db, contract.host_id)
    created: list[models.KhaiBaoTamTru] = []

    for pivot in pivots:
        existing = repo.get_by_contract_tenant(contract.id, pivot.tenant_id)
        if existing is not None:
            continue
        record = models.KhaiBaoTamTru(
            host_id=contract.host_id,
            tenant_id=pivot.tenant_id,
            contract_id=contract.id,
            check_in_at=check_in,
            status="pending",
            public_token=str(uuid.uuid4()),
            public_token_expires_at=expires,
        )
        db.add(record)
        created.append(record)

    if created:
        db.flush()

    return created


def auto_create_for_reservation(
    db: Session,
    reservation: models.Reservation,
) -> Optional[models.KhaiBaoTamTru]:
    """Phase 07 entry — create one record on check-in for the homestay guest.

    Reservations don't go through Tenant/ContractTenant; the guest data lives
    on the Reservation itself. We synthesise (or reuse) a Tenant row for the
    guest so the rest of the khai báo flow (templates, public link, dashboard
    counters) keeps working without branching.

    Idempotent on (reservation_id) — second call returns the existing row.
    Caller commits.
    """
    existing = (
        db.query(models.KhaiBaoTamTru)
        .filter(models.KhaiBaoTamTru.reservation_id == reservation.id)
        .first()
    )
    if existing is not None:
        return existing

    tenant = _resolve_or_create_guest_tenant(db, reservation)
    # Khai báo stores UTC; precise short-stay timestamps are Vietnam wall time.
    check_in = (reservation.check_in_at - timedelta(hours=7)
                if reservation.booking_mode else _parse_iso_date(reservation.check_in_date))
    expires = check_in + timedelta(days=PUBLIC_TOKEN_VALID_DAYS)

    record = models.KhaiBaoTamTru(
        host_id=reservation.host_id,
        tenant_id=tenant.id,
        contract_id=None,
        reservation_id=reservation.id,
        check_in_at=check_in,
        status="pending",
        public_token=str(uuid.uuid4()),
        public_token_expires_at=expires,
    )
    db.add(record)
    db.flush()
    return record


def _resolve_or_create_guest_tenant(
    db: Session, reservation: models.Reservation
) -> models.Tenant:
    """Reuse existing tenant by phone within this host scope, else create."""
    if reservation.guest_phone:
        existing = (
            db.query(models.Tenant)
            .filter(
                models.Tenant.host_id == reservation.host_id,
                models.Tenant.phone == reservation.guest_phone,
            )
            .first()
        )
        if existing is not None:
            return existing
    tenant = models.Tenant(
        host_id=reservation.host_id,
        full_name=reservation.guest_name,
        phone=reservation.guest_phone or "",
        email=reservation.guest_email,
    )
    db.add(tenant)
    db.flush()
    return tenant


def mark_declared(
    db: Session,
    record_id: int,
    host_id: int,
    declared_at: Optional[datetime] = None,
) -> models.KhaiBaoTamTru:
    """Host marks the record as declared. Idempotent (re-marking is a no-op)."""
    repo = KhaiBaoRepository(db, host_id)
    record = repo.get(record_id)
    if record is None:
        raise HTTPException(404, "Không tìm thấy bản khai báo")
    before = _snapshot(record)
    record.declared_at = declared_at or datetime.utcnow()
    record.status = "declared"
    record.updated_at = datetime.utcnow()
    db.flush()
    write_change_log(
        db,
        entity_type="khai_bao_tam_tru",
        entity_id=record.id,
        actor_id=host_id,
        action="status_change",
        before=before,
        after=_snapshot(record),
    )
    return record


def mark_skipped(
    db: Session,
    record_id: int,
    host_id: int,
    reason: str,
) -> models.KhaiBaoTamTru:
    """Host skips the record (guest left early). reason is mandatory."""
    repo = KhaiBaoRepository(db, host_id)
    record = repo.get(record_id)
    if record is None:
        raise HTTPException(404, "Không tìm thấy bản khai báo")
    if record.status == "declared":
        raise HTTPException(400, "Bản khai báo đã hoàn thành, không thể bỏ qua")
    before = _snapshot(record)
    record.status = "skipped"
    record.skip_reason = reason
    record.updated_at = datetime.utcnow()
    db.flush()
    write_change_log(
        db,
        entity_type="khai_bao_tam_tru",
        entity_id=record.id,
        actor_id=host_id,
        action="status_change",
        before=before,
        after=_snapshot(record),
    )
    return record


def sync_persisted_status(
    db: Session,
    records: list[models.KhaiBaoTamTru],
) -> None:
    """Drift fix: update persisted `status` to match computed status.

    Called from list endpoint — keeps dashboard count queries (which filter
    by `status` column) accurate without a cron job.
    """
    now = datetime.utcnow()
    changed = False
    for r in records:
        live = compute_status_now(r, now=now)
        if r.status != live:
            r.status = live
            r.updated_at = now
            changed = True
    if changed:
        db.flush()


def dashboard_counts(db: Session, host_id: int) -> dict:
    """Return {'pending': X, 'overdue': Y, 'declared': Z, 'skipped': W}.

    Compute fresh from records to avoid stale `status` column reads.
    """
    repo = KhaiBaoRepository(db, host_id)
    records = repo.list_filtered()
    sync_persisted_status(db, records)
    counts = {"pending": 0, "overdue": 0, "declared": 0, "skipped": 0}
    for r in records:
        counts[r.status] = counts.get(r.status, 0) + 1
    return counts


def _snapshot(record: models.KhaiBaoTamTru) -> dict:
    return {
        "id": record.id,
        "tenant_id": record.tenant_id,
        "contract_id": record.contract_id,
        "check_in_at": record.check_in_at.isoformat() if record.check_in_at else None,
        "declared_at": record.declared_at.isoformat() if record.declared_at else None,
        "status": record.status,
        "skip_reason": record.skip_reason,
    }
