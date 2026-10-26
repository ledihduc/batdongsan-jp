"""Invoice service — generate batch, send, record payment, credit note.

All mutations write change_logs and never commit (caller owns transaction).
Money rounded to whole VND (int) since no cents in Vietnamese currency.

Phase 09 additions:
  - CommissionSnapshot injected at invoice creation (seeds platform_fee = 0 per NFR-15).
  - CommissionSnapshot.snapshot_at_paid() called when invoice transitions to 'paid'.
    This locks commission_rate, commission_amount, platform_fee_pct, platform_fee_amount.
    Both fields are immutable after paid_at IS NOT NULL (service-layer guard).

v1 freemium: platform_fee_pct = 0. Override via PLATFORM_FEE_DEFAULT_PCT env var.
v1 NO auto-transfer: commission is tracked only. AC-35 / NHNN license O4 required.
"""

from __future__ import annotations

import uuid
from calendar import monthrange
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.repositories.audit import write_change_log
from app.repositories.contract_repository import ContractRepository
from app.repositories.invoice_repository import InvoiceRepository
from app.repositories.meter_reading_repository import MeterReadingRepository
from app.repositories.payment_repository import PaymentRepository
from app.repositories.room_repository import RoomRepository
from app.repositories.service_fee_repository import ServiceFeeRepository
from app.services import gia_tien_ich, tien_ich_phong
from app.schemas.invoice import (
    CreditNoteCreate,
    GenerateBatchRequest,
    RecordPaymentRequest,
)
from app.services.commission.commission_snapshot import CommissionSnapshot

# Module-level singleton — stateless (safe to share across requests)
_commission_snapshot = CommissionSnapshot()

PUBLIC_TOKEN_TTL_DAYS = 90
DEFAULT_DUE_DAYS = 7


# ── helpers ──────────────────────────────────────────────────────────────────

def _round_vnd(value: float) -> float:
    """Round to whole VND (no fractional cents)."""
    return float(round(value))


def _period_range(month: str) -> tuple[str, str]:
    """Convert 'YYYY-MM' → ('YYYY-MM-01', 'YYYY-MM-DD' last day)."""
    year = int(month[:4])
    mon = int(month[5:])
    last_day = monthrange(year, mon)[1]
    return f"{month}-01", f"{month}-{last_day:02d}"


def _invoice_number(contract_id: int, period_start: str) -> str:
    """E.g. 'INV-202607-C42'."""
    return f"INV-{period_start[:7].replace('-', '')}-C{contract_id}"


def _invoice_snapshot(invoice: models.Invoice) -> dict:
    return {
        "id": invoice.id,
        "status": invoice.status,
        "total_amount": invoice.total_amount,
        "paid_amount": invoice.paid_amount,
        "invoice_number": invoice.invoice_number,
        "period_start": invoice.period_start,
        "period_end": invoice.period_end,
    }


# ── generate batch ───────────────────────────────────────────────────────────

def generate_batch(
    db: Session,
    payload: GenerateBatchRequest,
    host_id: int,
) -> list[models.Invoice]:
    """Generate draft invoices for all active contracts in a building for a month.

    Idempotent: re-running for same (contract, period) skips that contract.
    """
    contract_repo = ContractRepository(db, host_id)
    room_repo = RoomRepository(db, host_id)

    # Active contracts whose room belongs to this building
    created: list[models.Invoice] = []
    for contract in contract_repo.list(status="active"):
        room = room_repo.get(contract.room_id)
        if room is None or room.building_id != payload.building_id:
            continue
        invoice = _lap_hoa_don_hop_dong(
            db,
            host_id,
            contract,
            room,
            month=payload.month,
            don_gia_dien=payload.electricity_unit_price,
            don_gia_nuoc=payload.water_unit_price,
        )
        if invoice is not None:
            created.append(invoice)
    return created


def lap_hoa_don_thang_nay(
    db: Session, host_id: int, contract_id: int, month: str
) -> tuple[models.Invoice, bool]:
    """Hoá đơn tháng `month` cho MỘT hợp đồng — nút "Lập hóa đơn tháng này" ở hồ sơ phòng.

    Trả `(hoá đơn, đã_có_từ_trước)`. Bấm hai lần không sinh hai hoá đơn: kỳ đã
    có thì trả lại đúng hoá đơn đó để màn hình mở ra, chứ không báo lỗi.
    """
    contract = ContractRepository(db, host_id).get(contract_id)
    room = (
        RoomRepository(db, host_id).get(contract.room_id)
        if contract is not None
        else None
    )
    # 404 chung cho "không phải của bạn" và "đã hết hiệu lực" — tách ra là
    # xác nhận hợp đồng của người khác tồn tại.
    if contract is None or contract.status != "active" or room is None:
        raise HTTPException(404, "Không tìm thấy hợp đồng đang hiệu lực")
    period_start, period_end = _period_range(month)
    co_san = InvoiceRepository(db, host_id).get_for_contract_period(
        contract.id, period_start, period_end
    )
    if co_san is not None:
        return co_san, True
    invoice = _lap_hoa_don_hop_dong(db, host_id, contract, room, month=month)
    assert invoice is not None  # vừa kiểm kỳ này chưa có hoá đơn
    return invoice, False


def han_dong_hoa_don(ngay_thanh_toan: Optional[int], hom_nay: date) -> date:
    """Hạn đóng của hoá đơn lập hôm nay.

    Hợp đồng có "ngày thu tiền hàng tháng" (migration 0108) → lần gần nhất ngày
    đó rơi vào, tính cả hôm nay; tháng thiếu ngày (31 → tháng 2) lấy ngày cuối
    tháng. Chưa khai → như trước: hôm nay + DEFAULT_DUE_DAYS.
    """
    if not ngay_thanh_toan:
        return hom_nay + timedelta(days=DEFAULT_DUE_DAYS)
    nam, thang = hom_nay.year, hom_nay.month
    han = hom_nay
    for _ in range(2):
        han = date(nam, thang, min(ngay_thanh_toan, monthrange(nam, thang)[1]))
        if han >= hom_nay:
            break
        nam, thang = (nam + 1, 1) if thang == 12 else (nam, thang + 1)
    return han


def dung_dong_tien(
    db: Session,
    host_id: int,
    contract: models.Contract,
    room: models.Room,
    *,
    month: str,
    don_gia_dien: Optional[float] = None,
    don_gia_nuoc: Optional[float] = None,
    dich_vu_chon: Optional[dict] = None,
    giam_tru: float = 0,
) -> list[models.InvoiceLineItem]:
    """Dựng CÁC DÒNG TIỀN của một hợp đồng trong một tháng — chưa ghi gì vào DB.

    MỘT chỗ duy nhất dựng dòng tiền, dùng cho cả ba đường: lô hoá đơn cả toà,
    nút "Lập hoá đơn tháng này", và bản XEM TRƯỚC ở trang "Dịch vụ & hoá đơn".
    Tách ra vì bản xem trước lệch hoá đơn thật dù chỉ một nghìn đồng là chủ nhà
    mất lòng tin vào cả màn.

    Dòng trả về CHƯA có `invoice_id` — người gọi gán sau khi tạo hoá đơn.
    """
    period_start, period_end = _period_range(month)
    meter_repo = MeterReadingRepository(db, host_id)
    fee_repo = ServiceFeeRepository(db, host_id)

    # Build line items
    line_items: list[models.InvoiceLineItem] = []
    sort_order = 0

    # 1) Rent
    rent_amount = _round_vnd(contract.monthly_rent)
    line_items.append(models.InvoiceLineItem(
        category="rent",
        description=f"Tiền nhà tháng {month}",
        quantity=1,
        unit_price=rent_amount,
        amount=rent_amount,
        sort_order=sort_order,
    ))
    sort_order += 1

    # 2) Electricity (latest reading − previous month reading)
    latest = meter_repo.latest_for_room(contract.room_id, before_date=period_end)
    previous = meter_repo.latest_for_room(contract.room_id, before_date=period_start)
    if latest is not None and previous is not None:
        kwh_used = max(0.0, latest.electricity_kwh - previous.electricity_kwh)
        m3_used = max(0.0, latest.water_m3 - previous.water_m3)
    else:
        kwh_used = 0.0
        m3_used = 0.0

    # Đơn giá: lô ghi đè nếu người dùng điền, không thì hỏi TỪNG PHÒNG
    # (phòng khai riêng → toà khai chung → hằng số). Trước migration 0104
    # chỉ có nhánh ghi đè, nên mọi phòng trong toà bị áp cùng một giá.
    gia_dien_ap = (
        don_gia_dien if don_gia_dien is not None else gia_tien_ich.gia_dien(db, room)
    )
    gia_nuoc_ap = (
        don_gia_nuoc if don_gia_nuoc is not None else gia_tien_ich.gia_nuoc(db, room)
    )

    if kwh_used > 0:
        elec_amount = _round_vnd(kwh_used * gia_dien_ap)
        line_items.append(models.InvoiceLineItem(
            category="electricity",
            description=f"Tiền điện ({kwh_used:.0f} kWh)",
            quantity=kwh_used,
            unit_price=gia_dien_ap,
            amount=elec_amount,
            sort_order=sort_order,
        ))
        sort_order += 1

    # Nước THEO NGƯỜI (migration 0136): đơn giá × số người ở, không đọc công tơ.
    so_nguoi = gia_tien_ich.so_nguoi(db, contract)
    if gia_tien_ich.nuoc_theo_nguoi(room):
        if so_nguoi > 0 and gia_nuoc_ap > 0:
            line_items.append(models.InvoiceLineItem(
                category="water",
                description=f"Tiền nước ({so_nguoi} người)",
                quantity=so_nguoi,
                unit_price=gia_nuoc_ap,
                amount=_round_vnd(so_nguoi * gia_nuoc_ap),
                sort_order=sort_order,
            ))
            sort_order += 1
    elif m3_used > 0:
        water_amount = _round_vnd(m3_used * gia_nuoc_ap)
        line_items.append(models.InvoiceLineItem(
            category="water",
            description=f"Tiền nước ({m3_used:.0f} m3)",
            quantity=m3_used,
            unit_price=gia_nuoc_ap,
            amount=water_amount,
            sort_order=sort_order,
        ))
        sort_order += 1

    # Phí dịch vụ khai ở PHÒNG (migration 0104) — một khoản gộp, mô tả liệt
    # kê gồm những gì. Cộng dồn với phí theo hợp đồng ở dưới chứ không thay
    # thế: hai nguồn khác nhau, phòng nào cũng có cái đầu, chỉ hợp đồng đã
    # ký mới có cái sau.
    phi_phong = gia_tien_ich.phi_dich_vu(db, room)
    if phi_phong > 0:
        gom = tien_ich_phong.ten_dich_vu(room.dich_vu_gom or [])
        line_items.append(models.InvoiceLineItem(
            category="service",
            description=(
                f"Dịch vụ ({', '.join(gom).lower()})" if gom else "Phí dịch vụ"
            ),
            quantity=1,
            unit_price=phi_phong,
            amount=_round_vnd(phi_phong),
            sort_order=sort_order,
        ))
        sort_order += 1

    # 3) Dịch vụ.
    #
    # `dich_vu_chon` là lựa chọn của THÁNG NÀY ở trang "Dịch vụ & hoá đơn":
    # {service_fee_id: số lượng}. Nó có thể chứa dịch vụ CHƯA gắn vào hợp đồng —
    # người dùng vừa bật nút — và bản xem trước phải tính ngay, không thì bấm
    # bật mà con số trên màn không nhúc nhích. Việc gắn vào hợp đồng để tháng
    # sau mặc định có là chuyện của lúc CHỐT.
    #
    # `None` = giữ nết cũ: mọi dịch vụ đã gắn, mỗi thứ một lần — lô hoá đơn cả
    # toà đi đường này.
    gan = {p.service_fee_id: p for p in fee_repo.list_for_contract(contract.id)}
    if dich_vu_chon is None:
        can_tinh = [(fid, 1.0) for fid in gan]
    else:
        can_tinh = [(fid, float(sl or 0)) for fid, sl in dich_vu_chon.items()]
    for fee_id, so_luong in can_tinh:
        if so_luong <= 0:
            continue
        pivot = gan.get(fee_id)
        fee = db.get(models.ServiceFee, fee_id)
        if fee is None and pivot is None:
            continue
        # Dịch vụ của toà khác lọt vào thì bỏ, đừng tính tiền nhầm toà.
        if fee is not None and fee.building_id != room.building_id:
            continue
        don_gia = float((pivot.monthly_amount if pivot is not None else fee.unit_price) or 0)
        # Tên thật của dịch vụ, không phải "Dịch vụ #7": hoá đơn này gửi cho
        # khách đọc, in ra số id thô là bắt họ đoán.
        ten = (fee.name if fee is not None else "") or f"Dịch vụ #{fee_id}"
        if fee is not None and fee.cach_tinh == gia_tien_ich.THEO_NGUOI:
            # Theo người: số lượng LÀ số người ở, không phải số lượt.
            line_items.append(models.InvoiceLineItem(
                category="service",
                description=f"{ten} ({so_nguoi} người)",
                quantity=so_nguoi,
                unit_price=don_gia,
                amount=_round_vnd(don_gia * so_nguoi),
                sort_order=sort_order,
            ))
            sort_order += 1
            continue
        line_items.append(models.InvoiceLineItem(
            category="service",
            description=ten if so_luong == 1 else f"{ten} x{so_luong:g}",
            quantity=so_luong,
            unit_price=don_gia,
            amount=_round_vnd(don_gia * so_luong),
            sort_order=sort_order,
        ))
        sort_order += 1

    # 4) Giảm trừ (ưu đãi, bù cọc...) — một dòng ÂM, không phải sửa tổng.
    # Sửa tổng thì hoá đơn in ra không giải thích được vì sao lệch.
    if giam_tru and giam_tru > 0:
        line_items.append(models.InvoiceLineItem(
            category="adjustment",
            description="Giảm trừ",
            quantity=1,
            unit_price=-_round_vnd(giam_tru),
            amount=-_round_vnd(giam_tru),
            sort_order=sort_order,
        ))
        sort_order += 1

    return line_items


def _lap_hoa_don_hop_dong(
    db: Session,
    host_id: int,
    contract: models.Contract,
    room: models.Room,
    *,
    month: str,
    don_gia_dien: Optional[float] = None,
    don_gia_nuoc: Optional[float] = None,
    dich_vu_chon: Optional[dict] = None,
    giam_tru: float = 0,
) -> Optional[models.Invoice]:
    """Hoá đơn nháp của MỘT hợp đồng cho một tháng.

    Dùng chung cho lô cả toà và nút "Lập hóa đơn tháng này" của hồ sơ phòng: hai
    đường tự dựng dòng tiền riêng là hai hoá đơn khác nhau cho cùng một phòng
    cùng một tháng. `None` khi kỳ đó đã có hoá đơn (idempotent). `don_gia_*` là
    đơn giá lô ghi đè; `None` thì hỏi giá của chính phòng.
    """
    period_start, period_end = _period_range(month)
    issued_date = date.today().isoformat()
    due_date = han_dong_hoa_don(contract.ngay_thanh_toan, date.today()).isoformat()

    invoice_repo = InvoiceRepository(db, host_id)

    # Idempotency check
    if invoice_repo.get_for_contract_period(contract.id, period_start, period_end):
        return None

    line_items = dung_dong_tien(
        db,
        host_id,
        contract,
        room,
        month=month,
        don_gia_dien=don_gia_dien,
        don_gia_nuoc=don_gia_nuoc,
        dich_vu_chon=dich_vu_chon,
        giam_tru=giam_tru,
    )

    total = _round_vnd(sum(li.amount for li in line_items))

    invoice = models.Invoice(
        host_id=host_id,
        contract_id=contract.id,
        invoice_number=_invoice_number(contract.id, period_start),
        period_start=period_start,
        period_end=period_end,
        issued_date=issued_date,
        due_date=due_date,
        status="draft",
        total_amount=total,
        paid_amount=0,
    )
    db.add(invoice)
    db.flush()  # need invoice.id

    # Phase 09 NFR-15: seed platform_fee columns at creation (v1 default = 0).
    # commission_rate/commission_amount are locked later at paid_at.
    _commission_snapshot.snapshot_at_creation(invoice, db)

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


# ── send ─────────────────────────────────────────────────────────────────────

def send_invoice(db: Session, invoice_id: int, host_id: int) -> models.Invoice:
    """draft → sent. Generates public_token (UUIDv4) valid for 90 days."""
    invoice_repo = InvoiceRepository(db, host_id)
    invoice = invoice_repo.get(invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Hoá đơn không tồn tại")
    if invoice.status != "draft":
        raise HTTPException(
            status_code=400,
            detail=f"Chỉ gửi được hoá đơn ở trạng thái 'draft' (hiện tại: '{invoice.status}')",
        )

    before = _invoice_snapshot(invoice)
    invoice.status = "sent"
    invoice.public_token = str(uuid.uuid4())
    invoice.public_token_expires_at = datetime.utcnow() + timedelta(days=PUBLIC_TOKEN_TTL_DAYS)
    invoice.updated_at = datetime.utcnow()
    db.flush()

    write_change_log(
        db,
        entity_type="invoice",
        entity_id=invoice.id,
        actor_id=host_id,
        action="status_change",
        before=before,
        after=_invoice_snapshot(invoice),
    )
    return invoice


# ── record payment ───────────────────────────────────────────────────────────

def record_payment(
    db: Session,
    invoice_id: int,
    payload: RecordPaymentRequest,
    host_id: int,
) -> tuple[models.Invoice, models.Payment]:
    """Append a Payment row; lock invoice if SUM(payments) ≥ total_amount."""
    invoice_repo = InvoiceRepository(db, host_id)
    payment_repo = PaymentRepository(db, host_id)

    invoice = invoice_repo.get(invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Hoá đơn không tồn tại")
    if invoice.status == "cancelled":
        raise HTTPException(status_code=400, detail="Hoá đơn đã bị huỷ")
    if invoice.status == "paid":
        raise HTTPException(status_code=400, detail="Hoá đơn đã thanh toán đủ — không thể ghi nhận thêm")

    before = _invoice_snapshot(invoice)

    payment = models.Payment(
        host_id=host_id,
        invoice_id=invoice.id,
        amount=_round_vnd(payload.amount),
        method=payload.method,
        paid_at=payload.paid_at or datetime.utcnow(),
        note=payload.note,
    )
    db.add(payment)
    db.flush()

    total_paid = payment_repo.sum_for_invoice(invoice.id)
    invoice.paid_amount = _round_vnd(total_paid)
    if invoice.paid_amount + 0.5 >= invoice.total_amount:
        invoice.status = "paid"
        invoice.paid_at = datetime.utcnow()
        # Phase 09: lock commission + platform_fee snapshot at paid_at (NFR-15, AC-33, AC-37).
        # MUST be called after paid_at is set. Immutable after this point.
        _commission_snapshot.snapshot_at_paid(invoice, db)
    invoice.updated_at = datetime.utcnow()
    db.flush()

    write_change_log(
        db,
        entity_type="invoice",
        entity_id=invoice.id,
        actor_id=host_id,
        action="status_change" if invoice.status == "paid" else "update",
        before=before,
        after=_invoice_snapshot(invoice),
    )
    return invoice, payment


# ── credit note ──────────────────────────────────────────────────────────────

def create_credit_note(
    db: Session,
    invoice_id: int,
    payload: CreditNoteCreate,
    host_id: int,
) -> models.CreditNote:
    """Adjustment after invoice is paid. Original invoice stays status=paid."""
    invoice_repo = InvoiceRepository(db, host_id)
    invoice = invoice_repo.get(invoice_id)
    if not invoice:
        raise HTTPException(status_code=404, detail="Hoá đơn không tồn tại")
    if invoice.status != "paid":
        raise HTTPException(
            status_code=400,
            detail="Chỉ tạo credit note cho hoá đơn đã thanh toán",
        )

    note = models.CreditNote(
        host_id=host_id,
        original_invoice_id=invoice.id,
        amount=_round_vnd(payload.amount),
        reason=payload.reason,
        issued_date=payload.issued_date,
    )
    db.add(note)
    db.flush()

    write_change_log(
        db,
        entity_type="credit_note",
        entity_id=note.id,
        actor_id=host_id,
        action="create",
        before=None,
        after={
            "id": note.id,
            "original_invoice_id": note.original_invoice_id,
            "amount": note.amount,
            "reason": note.reason,
        },
    )
    return note


# ── debt aging ───────────────────────────────────────────────────────────────

def compute_debt_aging(db: Session, host_id: int) -> dict:
    """Bucket unpaid invoices by days overdue: 0-30 / 30-60 / >60."""
    invoice_repo = InvoiceRepository(db, host_id)
    unpaid = invoice_repo.list_unpaid()
    today = date.today()

    buckets: dict[str, dict] = {
        "0-30": {"bucket": "0-30", "count": 0, "total_amount": 0.0, "invoice_ids": []},
        "30-60": {"bucket": "30-60", "count": 0, "total_amount": 0.0, "invoice_ids": []},
        ">60": {"bucket": ">60", "count": 0, "total_amount": 0.0, "invoice_ids": []},
    }
    total_unpaid = 0.0
    for inv in unpaid:
        try:
            due = date.fromisoformat(inv.due_date)
        except ValueError:
            continue
        days_overdue = (today - due).days
        outstanding = max(0.0, inv.total_amount - inv.paid_amount)
        total_unpaid += outstanding
        if days_overdue <= 30:
            key = "0-30"
        elif days_overdue <= 60:
            key = "30-60"
        else:
            key = ">60"
        buckets[key]["count"] += 1
        buckets[key]["total_amount"] += outstanding
        buckets[key]["invoice_ids"].append(inv.id)

    return {"buckets": list(buckets.values()), "total_unpaid": _round_vnd(total_unpaid)}


def needs_reminder(db: Session, host_id: int) -> list[dict]:
    """List of unpaid invoices sorted by days overdue DESC. Joins contract → primary tenant."""
    invoice_repo = InvoiceRepository(db, host_id)
    unpaid = invoice_repo.list_unpaid()
    today = date.today()
    items: list[dict] = []
    for inv in unpaid:
        try:
            due = date.fromisoformat(inv.due_date)
        except ValueError:
            continue
        days_overdue = (today - due).days
        if days_overdue <= 0:
            continue
        contract = db.get(models.Contract, inv.contract_id)
        room = db.get(models.Room, contract.room_id) if contract else None
        # Primary tenant
        pivot = (
            db.query(models.ContractTenant)
            .filter(
                models.ContractTenant.contract_id == inv.contract_id,
                models.ContractTenant.is_primary.is_(True),
            )
            .first()
        )
        tenant = db.get(models.Tenant, pivot.tenant_id) if pivot else None
        items.append({
            "invoice_id": inv.id,
            "contract_id": inv.contract_id,
            "room_code": room.code if room else "",
            "tenant_name": tenant.full_name if tenant else "",
            "tenant_phone": tenant.phone if tenant else "",
            "days_overdue": days_overdue,
            "amount_due": _round_vnd(inv.total_amount - inv.paid_amount),
        })
    items.sort(key=lambda x: x["days_overdue"], reverse=True)
    return items
