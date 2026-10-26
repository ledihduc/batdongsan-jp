"""SQLAlchemy 2.0 model for JpInvoiceLine — multi-line JP invoice item.

Table: jp_invoice_lines

JP residential rental tax rules encoded in this model's constants:
  - 家賃 (rent) — non-taxable (住宅の貸付, 消費税法 6条)
  - 共益費 (management fee) — taxable 10%
  - 敷金/礼金/更新料/保証金 — non-taxable (deposit/refundable or by custom)
  - 仲介手数料 (brokerage) — taxable 10%
  See: https://www.nta.go.jp/taxes/shiraberu/taxanswer/shohi/6225.htm

Design decisions:
- Managed by migration 0150_jp_invoice_lines.
- All amounts stored as Numeric (exact) — never float.
- tax_treatment: 'taxable' | 'exempt' | 'zero_rated'
- org_id: multi-tenant isolation.
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


# Line type taxonomy — must match invoice line generator
LINE_TYPE_VALUES = (
    "rent",          # 家賃
    "management",    # 共益費
    "shikikin",      # 敷金
    "reikin",        # 礼金
    "koushinryo",    # 更新料
    "brokerage",     # 仲介手数料
    "hoshou",        # 保証金/保証料
    "other",         # その他
)

TAX_TREATMENT_VALUES = ("taxable", "exempt", "zero_rated")

# JP consumption tax rate (10% as of 2019)
JP_CONSUMPTION_TAX_RATE = Decimal("0.10")


class JpInvoiceLine(Base):
    """One line item of a JP invoice.

    Amounts:
      total_jpy = amount_jpy + tax_amount_jpy

    Tax rules by line_type (JP law; see module docstring):
      rent        → exempt
      management  → taxable
      shikikin    → exempt
      reikin      → exempt
      koushinryo  → exempt
      brokerage   → taxable
      hoshou      → exempt
      other       → caller-specified

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpInvoiceLine.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_invoice_lines"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    org_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    invoice_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Invoice UUID. No FK — cross-domain boundary.",
    )

    line_type: Mapped[str] = mapped_column(
        String(20), nullable=False,
        comment="rent|management|shikikin|reikin|koushinryo|brokerage|hoshou|other",
    )

    amount_jpy: Mapped[Decimal] = mapped_column(
        Numeric(12, 0), nullable=False,
        comment="Pre-tax amount in JPY.",
    )
    tax_treatment: Mapped[str] = mapped_column(
        String(20), nullable=False,
        comment="taxable | exempt | zero_rated",
    )
    tax_amount_jpy: Mapped[Decimal] = mapped_column(
        Numeric(12, 0), nullable=False, default=Decimal("0"),
        comment="Consumption tax in JPY. 0 for exempt/zero_rated lines.",
    )

    description: Mapped[Optional[str]] = mapped_column(
        String(200), nullable=True,
        comment="Human-readable label (e.g. '家賃 2025年1月分').",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
