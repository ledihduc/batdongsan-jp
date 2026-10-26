from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

class Invoice(Base):
    """Monthly (or move-out) rent invoice. Immutable after status=paid.

    Lifecycle: draft → sent → paid (or → overdue → paid) | cancelled.
    public_token is a UUIDv4 string used for unauth /public/invoices/{token} HTML render.
    """
    __tablename__ = "invoices"
    __table_args__ = (
        # Prevent dup-period drafts for same contract
        UniqueConstraint(
            "contract_id", "period_start", "period_end",
            name="uq_invoices_contract_period",
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    contract_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="RESTRICT"), index=True
    )
    invoice_number: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    period_start: Mapped[str] = mapped_column(String(20))  # ISO date
    period_end: Mapped[str] = mapped_column(String(20))
    issued_date: Mapped[str] = mapped_column(String(20))
    due_date: Mapped[str] = mapped_column(String(20))
    # Status: draft | sent | paid | overdue | cancelled
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    total_amount: Mapped[float] = mapped_column(Float, default=0)
    paid_amount: Mapped[float] = mapped_column(Float, default=0)
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    public_token: Mapped[Optional[str]] = mapped_column(
        String(36), unique=True, nullable=True, index=True
    )
    public_token_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    # Phase 04 analytics: commission snapshot (NULL = no commission / legacy invoice).
    # commission_amount is computed from Reservation.commission_rate × total_amount
    # at Invoice generation time and locked. Not reversed by CreditNote (per Q3 decision).
    commission_rate: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    commission_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)

    # ── Phase delegation (migration 0034) — NFR-15 platform fee forward-compat ──
    # v1 = NULL (FREE tier). v1.5 freemium: set pct at invoice generation time;
    # platform_fee_amount locked at paid_at (mirrors commission immutability).
    # NUMERIC(5,4) supports up to 99.9999% — allows fractional percentage precision.
    platform_fee_pct: Mapped[Optional[object]] = mapped_column(Numeric(5, 4), nullable=True)
    platform_fee_amount: Mapped[Optional[object]] = mapped_column(Numeric(15, 0), nullable=True)


class InvoiceLineItem(Base):
    """Children of Invoice.

    category enum: rent | electricity | water | service | deposit_refund | damage_deduction | adjustment
    amount can be negative (deposit_refund line lowers total).
    """
    __tablename__ = "invoice_line_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    invoice_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("invoices.id", ondelete="CASCADE"), index=True
    )
    category: Mapped[str] = mapped_column(String(30))
    description: Mapped[str] = mapped_column(String(300), default="")
    quantity: Mapped[float] = mapped_column(Float, default=1)
    unit_price: Mapped[float] = mapped_column(Float, default=0)
    amount: Mapped[float] = mapped_column(Float, default=0)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)


class Payment(Base):
    """Payment record against an Invoice. Multiple allowed (partial pay).

    Invoice transitions to status=paid when SUM(amount) >= invoice.total_amount.
    """
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    invoice_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("invoices.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[float] = mapped_column(Float)
    # Method: cash | bank_transfer | other
    method: Mapped[str] = mapped_column(String(20), default="cash")
    paid_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class CreditNote(Base):
    """Adjustment after Invoice is paid (immutable).

    Records refund/discount applied retroactively. Original Invoice remains status=paid.
    """
    __tablename__ = "credit_notes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    original_invoice_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("invoices.id", ondelete="RESTRICT"), index=True
    )
    amount: Mapped[float] = mapped_column(Float)
    reason: Mapped[str] = mapped_column(Text, default="")
    issued_date: Mapped[str] = mapped_column(String(20))  # ISO date
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


