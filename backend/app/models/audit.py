from app.models._shared import *  # noqa: F401,F403 — Base/JSONList/now_utc + sqlalchemy types

# ── Phase 09: TT200 Export audit + versioning ─────────────────────────────────


class AuditLog(Base):
    """Per-action audit trail for legal compliance.

    Tracks every export attempt (success + failure).
    action: 'export_tt200' | future actions.
    """
    __tablename__ = "audit_logs"
    __table_args__ = (
        Index("ix_audit_logs_host_action_created", "host_id", "action", "created_at"),
        # NFR-03: composite index for delegation audit queries
        Index("ix_audit_logs_delegation_created", "acted_via_delegation_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    action: Mapped[str] = mapped_column(String(50), nullable=False)
    # period: "YYYY-MM" for export_tt200; NULL for other actions
    period: Mapped[Optional[str]] = mapped_column(String(7), nullable=True)
    success: Mapped[bool] = mapped_column(Boolean, nullable=False)
    # ip: up to 45 chars for IPv6
    ip: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    # extra: arbitrary JSON blob for future extensibility
    extra: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)

    # ── Phase delegation (migration 0033) ────────────────────────────────────
    # Explicit actor (separate from host_id which = owner)
    actor_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Owner when actor is an operator (dual-identity logging)
    on_behalf_of_user_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    # Delegation that authorized this action.
    # FK constraint in DB (migration 0033 Postgres-only) but NOT declared here
    # to avoid table resolution error when app.domain not imported.
    acted_via_delegation_id: Mapped[Optional[str]] = mapped_column(
        String(36), nullable=True
    )
    # AC-44 4-tier retention
    retention_tier: Mapped[str] = mapped_column(
        String(10), nullable=False, default="hot"
    )


class Tt200Export(Base):
    """Versioned TT200 export record for immutability guarantee.

    Each successful export writes one row. Re-exporting same period increments version.
    sha256 is the hex digest of the generated xlsx file bytes.
    UNIQUE(host_id, period, version) prevents duplicate version numbers.
    """
    __tablename__ = "tt200_exports"
    __table_args__ = (
        UniqueConstraint(
            "host_id", "period", "version",
            name="uq_tt200_exports_host_period_version",
        ),
        Index("ix_tt200_exports_host_period_version", "host_id", "period", "version"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    host_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # period: "YYYY-MM"
    period: Mapped[str] = mapped_column(String(7), nullable=False)
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    # sha256 hex digest of xlsx file bytes (64 chars)
    sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    exported_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    ip: Mapped[Optional[str]] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)


class VerificationRequest(Base):
    """Yêu cầu thẩm định chất lượng nhà trọ (Phase 2).

    Chủ tạo yêu cầu → admin/thẩm-định-viên kiểm tra thực tế → gắn verified_star
    vào houses. Phí (fee_amount) hiện DEFERRED (chờ Payment core).
    """

    __tablename__ = "verification_requests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    house_id: Mapped[int] = mapped_column(Integer, index=True)
    host_id: Mapped[int] = mapped_column(Integer, index=True)
    # requested | inspecting | done | rejected
    status: Mapped[str] = mapped_column(String(20), default="requested")
    fee_amount: Mapped[int] = mapped_column(Integer, default=0)
    # deferred | manual_confirmed | paid
    payment_status: Mapped[str] = mapped_column(String(20), default="deferred")
    verified_star: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    criteria_json: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    note: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    assignee_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now_utc)
    completed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)


