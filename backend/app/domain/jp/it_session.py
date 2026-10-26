"""SQLAlchemy 2.0 model for JpItSession — IT重説 session record.

Table: jp_it_sessions

Legal requirement: IT重説 (宅地建物取引業法 35条改正) mandates a licensed 宅建士
conduct an online explanation before the tenant signs the rental contract.
Tenant must explicitly consent (tenant_consent_at) before session entry.

Design decisions:
- Managed by migration 0154_jp_it_sessions.
- No FK to jp_viewings or users — cross-domain isolation.
- org_id: multi-tenant isolation.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


IT_SESSION_STATUS_VALUES = ("scheduled", "in_progress", "completed", "cancelled")


class JpItSession(Base):
    """IT重説 session record.

    Org scoping:
        Every repository list query MUST include:
            .filter(JpItSession.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_it_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    viewing_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="JpViewing.id. No FK — cross-domain boundary.",
    )
    takken_shi_id: Mapped[int] = mapped_column(
        Integer, nullable=False,
        comment="User ID of 宅建士 (licensed agent).",
    )

    scheduled_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False,
        comment="Planned session start time (stored as UTC).",
    )

    zoom_meeting_id: Mapped[Optional[str]] = mapped_column(
        String(128), nullable=True,
        comment="Zoom Meeting ID. Null until Zoom API responds.",
    )
    zoom_join_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True,
        comment="Tenant-facing Zoom join URL.",
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="scheduled",
        comment="scheduled | in_progress | completed | cancelled",
    )

    tenant_consent_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment="When tenant gave IT重説 consent. Null = not yet consented.",
    )
    recording_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True,
        comment="Zoom cloud recording URL (short-lived signed).",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
