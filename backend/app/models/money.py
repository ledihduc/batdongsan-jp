"""P09 immutable record-only money ledger; no transfer execution lives here."""

from app.models._shared import *  # noqa: F401,F403


class PlatformPayment(Base):
    __tablename__ = "platform_payments"
    __table_args__ = (
        UniqueConstraint("source_type", "source_id", "external_reference", name="uq_platform_payment_source_ref"),
        CheckConstraint("amount >= 0", name="ck_platform_payment_amount_nonnegative"),
    )
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    source_type: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    source_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    payer_user_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    currency: Mapped[str] = mapped_column(String(3), default="VND", nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="RECORDED", nullable=False, index=True)
    method: Mapped[str] = mapped_column(String(30), default="MANUAL_PROOF", nullable=False)
    external_reference: Mapped[str] = mapped_column(String(120), nullable=False)
    evidence_urls: Mapped[list] = mapped_column(JSONList, default=list)
    recorded_by_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    paid_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class PaymentAllocation(Base):
    __tablename__ = "payment_allocations"
    __table_args__ = (UniqueConstraint("payment_id", "allocation_type", "beneficiary_user_id", name="uq_payment_allocation_bucket"), CheckConstraint("amount >= 0", name="ck_payment_allocation_nonnegative"))
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    payment_id: Mapped[int] = mapped_column(Integer, ForeignKey("platform_payments.id", ondelete="CASCADE"), nullable=False, index=True)
    allocation_type: Mapped[str] = mapped_column(String(30), nullable=False)
    beneficiary_user_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    rule_version: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class OwnerSettlement(Base):
    __tablename__ = "owner_settlements"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    owner_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    period: Mapped[str] = mapped_column(String(7), nullable=False, index=True)
    gross_amount: Mapped[float] = mapped_column(Float, nullable=False)
    net_amount: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="PENDING_MANUAL", nullable=False, index=True)
    snapshot: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    settled_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class SaleCommission(Base):
    __tablename__ = "sale_commissions"
    __table_args__ = (UniqueConstraint("source_type", "source_id", "sale_user_id", name="uq_sale_commission_source"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    sale_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    source_type: Mapped[str] = mapped_column(String(30), nullable=False)
    source_id: Mapped[int] = mapped_column(Integer, nullable=False)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    rule_snapshot: Mapped[dict] = mapped_column(JSON, default=dict, nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="DEFERRED_POLICY", nullable=False, index=True)
    recognized_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)


class CommissionPayout(Base):
    __tablename__ = "commission_payouts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    commission_id: Mapped[int] = mapped_column(Integer, ForeignKey("sale_commissions.id", ondelete="RESTRICT"), nullable=False, index=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="NOT_SCHEDULED", nullable=False)
    external_reference: Mapped[Optional[str]] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    paid_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


class MoneyRefund(Base):
    __tablename__ = "money_refunds"
    __table_args__ = (CheckConstraint("amount >= 0", name="ck_money_refund_nonnegative"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    payment_id: Mapped[int] = mapped_column(Integer, ForeignKey("platform_payments.id", ondelete="RESTRICT"), nullable=False, index=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    reason_code: Mapped[str] = mapped_column(String(40), nullable=False)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(24), default="RECORDED", nullable=False)
    recorded_by_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
