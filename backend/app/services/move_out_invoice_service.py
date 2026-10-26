"""Move-out final invoice — prorate rent + final meter + deposit refund / damage.

Called from contract_service.terminate_contract after the contract is marked terminated.
Generates an invoice in status='sent' with public_token issued (skip draft for move-out).
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.invoice_repository import InvoiceRepository
from app.repositories.meter_reading_repository import MeterReadingRepository
from app.repositories.service_fee_repository import ServiceFeeRepository
from app.services import gia_tien_ich
from app.services.invoice_service import (
    DEFAULT_DUE_DAYS,
    PUBLIC_TOKEN_TTL_DAYS,
    _invoice_snapshot,
    _round_vnd,
)

# Default per-month divisor — use 30 to match BA spec.
DAYS_PER_MONTH = 30


def _period_start_for_final(
    db: Session, contract: models.Contract, host_id: int
) -> str:
    """Determine the start of the final billing window.

    Use the day after the most recent paid/sent invoice period_end. If no
    prior invoice exists, fall back to contract.start_date.
    """
    invoice_repo = InvoiceRepository(db, host_id)
    prior = (
        invoice_repo._base_query()
        .filter(models.Invoice.contract_id == contract.id)
        .order_by(models.Invoice.period_end.desc())
        .first()
    )
    if prior is None:
        return contract.start_date
    try:
        last_end = date.fromisoformat(prior.period_end)
    except ValueError:
        return contract.start_date
    return (last_end + timedelta(days=1)).isoformat()


def generate_final_invoice(
    db: Session,
    contract: models.Contract,
    actual_end_date: str,
    host_id: int,
    deposit_refund_amount: float = 0,
    damage_deduction_amount: float = 0,
    electricity_unit_price: Optional[float] = None,
    water_unit_price: Optional[float] = None,
) -> models.Invoice:
    """Build and persist the move-out invoice. Caller still owns the transaction."""
    period_start = _period_start_for_final(db, contract, host_id)
    period_end = actual_end_date

    try:
        start_d = date.fromisoformat(period_start)
        end_d = date.fromisoformat(actual_end_date)
        days_used = max(1, (end_d - start_d).days + 1)
    except ValueError:
        days_used = DAYS_PER_MONTH

    line_items: list[models.InvoiceLineItem] = []
    sort_order = 0

    # 1) Prorate rent
    prorate_rent = _round_vnd(contract.monthly_rent * days_used / DAYS_PER_MONTH)
    line_items.append(models.InvoiceLineItem(
        category="rent",
        description=f"Tiền nhà ({days_used} ngày)",
        quantity=days_used,
        unit_price=contract.monthly_rent / DAYS_PER_MONTH,
        amount=prorate_rent,
        sort_order=sort_order,
    ))
    sort_order += 1

    # 2) Final meter reading (latest before period_end vs latest before period_start)
    meter_repo = MeterReadingRepository(db, host_id)
    final = meter_repo.latest_for_room(contract.room_id, before_date=None)
    previous = meter_repo.latest_for_room(contract.room_id, before_date=period_start)
    if final is not None and previous is not None:
        kwh_used = max(0.0, final.electricity_kwh - previous.electricity_kwh)
        m3_used = max(0.0, final.water_m3 - previous.water_m3)
        # `None` = dùng giá của chính phòng này (migration 0104). Hoá đơn trả
        # phòng phải ra cùng đơn giá với hoá đơn hàng tháng của đúng phòng đó —
        # hai con số khác nhau ở lần cuối cùng là lúc dễ cãi nhau nhất.
        room = db.get(models.Room, contract.room_id)
        don_gia_dien = (
            electricity_unit_price
            if electricity_unit_price is not None
            else gia_tien_ich.gia_dien(db, room)
        )
        don_gia_nuoc = (
            water_unit_price
            if water_unit_price is not None
            else gia_tien_ich.gia_nuoc(db, room)
        )
        if kwh_used > 0:
            elec_amount = _round_vnd(kwh_used * don_gia_dien)
            line_items.append(models.InvoiceLineItem(
                category="electricity",
                description=f"Tiền điện cuối kỳ ({kwh_used:.0f} kWh)",
                quantity=kwh_used,
                unit_price=don_gia_dien,
                amount=elec_amount,
                sort_order=sort_order,
            ))
            sort_order += 1
        if m3_used > 0:
            water_amount = _round_vnd(m3_used * don_gia_nuoc)
            line_items.append(models.InvoiceLineItem(
                category="water",
                description=f"Tiền nước cuối kỳ ({m3_used:.0f} m3)",
                quantity=m3_used,
                unit_price=don_gia_nuoc,
                amount=water_amount,
                sort_order=sort_order,
            ))
            sort_order += 1

    # 3) Service fees prorated
    fee_repo = ServiceFeeRepository(db, host_id)
    for pivot in fee_repo.list_for_contract(contract.id):
        prorate_fee = _round_vnd(pivot.monthly_amount * days_used / DAYS_PER_MONTH)
        if prorate_fee > 0:
            line_items.append(models.InvoiceLineItem(
                category="service",
                description=f"Dịch vụ #{pivot.service_fee_id} ({days_used} ngày)",
                quantity=days_used,
                unit_price=pivot.monthly_amount / DAYS_PER_MONTH,
                amount=prorate_fee,
                sort_order=sort_order,
            ))
            sort_order += 1

    # 4) Deposit refund (negative amount lowers total)
    if deposit_refund_amount > 0:
        line_items.append(models.InvoiceLineItem(
            category="deposit_refund",
            description="Hoàn trả cọc",
            quantity=1,
            unit_price=-deposit_refund_amount,
            amount=_round_vnd(-deposit_refund_amount),
            sort_order=sort_order,
        ))
        sort_order += 1

    # 5) Damage deduction (positive amount raises total)
    if damage_deduction_amount > 0:
        line_items.append(models.InvoiceLineItem(
            category="damage_deduction",
            description="Khấu trừ hư hại",
            quantity=1,
            unit_price=damage_deduction_amount,
            amount=_round_vnd(damage_deduction_amount),
            sort_order=sort_order,
        ))
        sort_order += 1

    total = _round_vnd(sum(li.amount for li in line_items))
    today = date.today()
    invoice_number = f"INV-MOVEOUT-C{contract.id}-{today.strftime('%Y%m%d')}"

    invoice = models.Invoice(
        host_id=host_id,
        contract_id=contract.id,
        invoice_number=invoice_number,
        period_start=period_start,
        period_end=period_end,
        issued_date=today.isoformat(),
        due_date=(today + timedelta(days=DEFAULT_DUE_DAYS)).isoformat(),
        status="sent",
        total_amount=total,
        paid_amount=0,
        public_token=str(uuid.uuid4()),
        public_token_expires_at=datetime.utcnow() + timedelta(days=PUBLIC_TOKEN_TTL_DAYS),
    )
    db.add(invoice)
    db.flush()

    for li in line_items:
        li.invoice_id = invoice.id
        db.add(li)
    db.flush()

    write_change_log(
        db,
        entity_type="invoice",
        entity_id=invoice.id,
        actor_id=host_id,
        action="create",
        before=None,
        after=_invoice_snapshot(invoice),
    )
    return invoice
