"""P14 buy/sell transaction, deliberately separate from rental Stay/Invoice."""
from app.models._shared import *  # noqa: F401,F403


class SaleTransaction(Base):
    __tablename__ = "sale_transactions"
    __table_args__ = (UniqueConstraint("deal_id", name="uq_sale_transaction_deal"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    deal_id: Mapped[int] = mapped_column(Integer, ForeignKey("deals.id", ondelete="RESTRICT"), nullable=False, unique=True)
    buyer_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    seller_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    sale_user_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    stage: Mapped[str] = mapped_column(String(30), default="INTERESTED", nullable=False, index=True)
    offer_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    agreed_amount: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    lost_reason_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    lost_note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, onupdate=now_utc)


class SaleTransactionEvent(Base):
    __tablename__ = "sale_transaction_events"
    __table_args__ = (Index("ix_sale_transaction_event_tx_created", "transaction_id", "created_at"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    transaction_id: Mapped[int] = mapped_column(Integer, ForeignKey("sale_transactions.id", ondelete="CASCADE"), nullable=False, index=True)
    actor_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    actor_role: Mapped[str] = mapped_column(String(20), nullable=False)
    from_stage: Mapped[str] = mapped_column(String(30), nullable=False)
    to_stage: Mapped[str] = mapped_column(String(30), nullable=False)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc, index=True)


class SaleTransactionDocument(Base):
    __tablename__ = "sale_transaction_documents"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    transaction_id: Mapped[int] = mapped_column(Integer, ForeignKey("sale_transactions.id", ondelete="CASCADE"), nullable=False, index=True)
    document_type: Mapped[str] = mapped_column(String(40), nullable=False)
    file_url: Mapped[str] = mapped_column(String(500), nullable=False)
    uploaded_by_user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
