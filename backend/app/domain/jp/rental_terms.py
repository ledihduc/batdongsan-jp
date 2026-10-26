"""SQLAlchemy 2.0 model for JP rental terms (月額家賃/敷金/礼金/etc.).

Table: jp_rental_terms

LEGAL WARNING: JP rental money fields carry consumer law liability (不動産業法/消費者契約法).
These fields MUST NOT be coerced with VN pricing fields. This model owns the table.

Design decisions:
- Managed by migration 0143_jp_rental_terms (additive, nullable, idempotent).
- All money fields stored as Numeric (exact decimal) — never float.
- tax_treatment as string enum, not Python enum, to avoid migration churn on value changes.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# Valid tax_treatment values — documented here to avoid magic strings elsewhere.
TAX_TREATMENT_VALUES = ("included", "excluded", "exempt")


class JpRentalTerms(Base):
    """JP rental terms — chintai money fields for one listing.

    All monetary amounts in JPY (integer-precision Numeric).
    Deposit/fee multiples stored as Numeric(4,2) to allow 0.5-month granularity.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpRentalTerms.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_rental_terms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant broker org isolation (see module docstring)
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    # 月額家賃 — monthly rent (mandatory)
    monthly_rent_jpy: Mapped[Decimal] = mapped_column(
        Numeric(12, 0), nullable=False,
        comment="月額家賃 in JPY. Legal field — must not be zero.",
    )

    # 共益費 — management/common area fee
    management_fee_jpy: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(10, 0), nullable=True,
        comment="共益費 in JPY. Nullable if included in monthly rent.",
    )

    # 敷金 — security deposit (in months of rent)
    shikikin_months: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(4, 2), nullable=True,
        comment="敷金 in months of rent (e.g. 1.0). Nullable = none required.",
    )

    # 礼金 — key money non-refundable (in months of rent)
    reikin_months: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(4, 2), nullable=True,
        comment="礼金 in months of rent. Nullable = none required.",
    )

    # 保証金 — guarantee deposit (regional alternative to shikikin)
    hoshou_months: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(4, 2), nullable=True,
        comment="保証金 in months of rent. Regional alternative to shikikin.",
    )

    # 更新料 — lease renewal fee
    koushinryo_months: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(4, 2), nullable=True,
        comment="更新料 in months of rent. Charged at lease renewal.",
    )

    # 仲介手数料率 — brokerage fee rate (legal max 1.1 by 宅建業法)
    brokerage_rate: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(5, 4), nullable=True,
        comment="仲介手数料率 as decimal (1.1 = 110% of one month). Legal max 1.1.",
    )

    # 保証会社手数料 — guarantee company fee
    hoshou_fee_jpy: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(10, 0), nullable=True,
        comment="保証会社手数料 in JPY. One-time payment at contract signing.",
    )

    # 消費税扱い — consumption tax handling
    tax_treatment: Mapped[str] = mapped_column(
        String(20), nullable=False, default="included",
        comment="Tax treatment: included | excluded | exempt. Legal field.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
