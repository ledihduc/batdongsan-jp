from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

# ── Phase 05: Khai báo tạm trú (residence declaration) ────────────────────────


class KhaiBaoTamTru(Base):
    """Per-tenant residence declaration record (one row per Tenant per stay).

    Auto-created when a Contract is created (Phase 05) or Reservation created
    (Phase 07). Host opens HTML public-link → screenshots/prints → submits at
    http://tbltkbtt.bocongan.gov.vn or via VNeID. Then marks 'declared' in app.

    Status:
        - pending: declared_at IS NULL AND now < check_in_at + 12h
        - overdue: declared_at IS NULL AND now >= check_in_at + 12h
        - declared: declared_at IS NOT NULL
        - skipped: host opted out (e.g., guest left early)

    Status persisted for index + dashboard count perf, but the authoritative
    value is recomputed in service layer on every read (no cron in MVP).

    public_token: UUIDv4 (122 bits entropy) — same String(36) pattern as Invoice
    for cross-DB compatibility (no PG-specific UUID dependency).
    """
    __tablename__ = "khai_bao_tam_tru"
    __table_args__ = (
        # Idempotent per (contract, tenant) — prevents dup auto-create
        UniqueConstraint(
            "contract_id", "tenant_id",
            name="uq_khai_bao_contract_tenant",
        ),
        Index("ix_khai_bao_host_status", "host_id", "status"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    tenant_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    contract_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("contracts.id", ondelete="CASCADE"), nullable=True, index=True
    )
    # reservation_id reserved for Phase 07 — column exists now to avoid second migration
    reservation_id: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, index=True
    )
    check_in_at: Mapped[datetime] = mapped_column(DateTime)
    declared_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    # Status: pending | declared | overdue | skipped
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    skip_reason: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    public_token: Mapped[str] = mapped_column(
        String(36), unique=True, index=True
    )
    public_token_expires_at: Mapped[datetime] = mapped_column(DateTime)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=now_utc, onupdate=now_utc
    )


