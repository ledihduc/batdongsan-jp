"""SQLAlchemy 2.0 model for JpUserConsent — APPI (個人情報保護法) consent record.

Table: jp_user_consents

Legal requirements:
- Consent records are APPEND-ONLY (immutable audit trail).
- Revocation = new row with revoked_at set, OR update revoked_at on existing row.
  The granted_at timestamp is NEVER modified.
- legal_hold=True rows must NOT be purged even after DSR deletion request.
- APPI requires consent records to be kept for audit.

Design decisions:
- Managed by migration 0153_jp_user_consents.
- ip_address and user_agent are PII — tagged for future field-level encryption.
- consent_version tracks which version of the consent text the user saw.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import Boolean, DateTime, Integer, LargeBinary, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid purpose values — must match consent capture service
PURPOSE_VALUES = (
    "service_use",          # 利用規約への同意 (mandatory)
    "marketing",            # マーケティング目的
    "analytics",            # 分析・改善目的
    "data_sharing_broker",  # 不動産業者への情報提供
    "data_sharing_hoshou",  # 保証会社への情報提供
)


class JpUserConsent(Base):
    """APPI consent record for a platform user.

    Append-only: never DELETE or UPDATE granted_at.
    To revoke: set revoked_at on the active row.
    To re-grant: insert a new row.

    PII fields: ip_address, user_agent — tagged for future field-level encryption.

    Filter: always filter by user_id + purpose + revoked_at IS NULL for active consent.
    """

    __tablename__ = "jp_user_consents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    user_id: Mapped[int] = mapped_column(
        Integer, nullable=False, index=True,
        comment="Platform user ID.",
    )

    purpose: Mapped[str] = mapped_column(
        String(40), nullable=False,
        comment=(
            "service_use | marketing | analytics "
            "| data_sharing_broker | data_sharing_hoshou"
        ),
    )

    consent_version: Mapped[str] = mapped_column(
        String(20), nullable=False, default="1.0",
        comment="Version of consent text shown to user. Increment when text changes.",
    )

    granted_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
        comment="When user granted consent. IMMUTABLE — never modify.",
    )
    revoked_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True,
        comment=(
            "When user revoked. Null = active consent. "
            "To revoke: set this field. Do NOT modify granted_at."
        ),
    )

    # Audit metadata — PII
    ip_address: Mapped[Optional[str]] = mapped_column(
        String(45), nullable=True,
        comment="IPv4 or IPv6 at grant time. pii=True",
    )
    user_agent: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True,
        comment="Browser/app user-agent at grant time. pii=True",
    )

    # Legal hold — set when DSR deletion is requested but row must be retained
    legal_hold: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False,
        comment="If True, row is exempt from DSR purge (legal requirement).",
    )

    # Encrypted PII fields — added in migration 0159.
    # Plaintext columns (ip_address, user_agent above) kept for 1 release → drop in P4.
    ip_address_encrypted: Mapped[Optional[bytes]] = mapped_column(
        LargeBinary, nullable=True,
        comment="Fernet-encrypted ip_address. Added 0159. Replaces plaintext in P4.",
    )
    user_agent_encrypted: Mapped[Optional[bytes]] = mapped_column(
        LargeBinary, nullable=True,
        comment="Fernet-encrypted user_agent. Added 0159. Replaces plaintext in P4.",
    )
