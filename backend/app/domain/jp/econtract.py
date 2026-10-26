"""SQLAlchemy 2.0 model for JpEContract — electronic contract via CloudSign.

Table: jp_econtracts

Design decisions:
- Managed by migration 0155_jp_econtracts.
- No FK to jp_tenant_applications — cross-domain isolation.
- org_id: multi-tenant isolation.
- remote_doc_id: CloudSign's document UUID; used for webhook correlation.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


ECONTRACT_STATUS_VALUES = ("draft", "sent", "viewed", "signed", "cancelled")


class JpEContract(Base):
    """Electronic contract record for JP rental application.

    Org scoping:
        Every repository list query MUST include:
            .filter(JpEContract.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_econtracts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    application_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="JpTenantApplication.id. No FK — cross-domain boundary.",
    )

    provider: Mapped[str] = mapped_column(
        String(32), nullable=False, default="cloudsign",
        comment="eSign provider (cloudsign).",
    )
    remote_doc_id: Mapped[Optional[str]] = mapped_column(
        String(128), nullable=True, index=True,
        comment="CloudSign document ID for webhook correlation.",
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="draft",
        comment="draft | sent | viewed | signed | cancelled",
    )

    signed_pdf_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True,
        comment="Signed PDF URL from CloudSign. Null until signed.",
    )
    template_version: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True,
        comment="Contract template version used. For audit.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
