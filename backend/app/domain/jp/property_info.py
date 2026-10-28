"""SQLAlchemy 2.0 model for JP property physical attributes.

Table: jp_property_info

Display of 間取り/専有面積/築年数/構造/向き is legally mandated under 宅建業法
for JP real estate listings. Missing these fields is a disclosure violation.

Design decisions:
- Managed by migration 0144_jp_property_info (additive, nullable, idempotent).
- layout/structure/orientation stored as string to avoid migration churn on enum expansion.
- org_id: multi-tenant isolation. Every repository list() MUST filter by org_id.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Date, DateTime, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


# 間取り layout values — documented for validation in schemas/jp/property_info.py
LAYOUT_VALUES = (
    "1K", "1DK", "1LDK",
    "2K", "2DK", "2LDK",
    "3K", "3DK", "3LDK",
    "4LDK+",
)

# 構造 structure values
STRUCTURE_VALUES = ("RC", "WOOD", "STEEL", "SRC")

# 向き orientation values
ORIENTATION_VALUES = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")


class JpPropertyInfo(Base):
    """JP property physical attributes — 間取り/面積/築年数/構造/向き.

    One record per listing (1:1 via listing_id in transit_access or denormalized join).

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(JpPropertyInfo.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_property_info"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Multi-tenant broker org isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )
    # Liên kết tới tin `houses` (cùng quy ước jp_transit_access.listing_id).
    listing_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="houses.id dạng chuỗi (D1, mig 0167). NULL = dữ liệu cũ chưa gắn tin.",
    )

    # 間取り — floor plan layout
    layout: Mapped[Optional[str]] = mapped_column(
        String(10), nullable=True,
        comment="間取り: 1K/1DK/1LDK/2K/2DK/2LDK/3K/3DK/3LDK/4LDK+",
    )

    # 専有面積 — exclusive floor area
    floor_area_sqm: Mapped[Optional[Decimal]] = mapped_column(
        Numeric(7, 2), nullable=True,
        comment="専有面積 in m². Display mandatory per 宅建業法.",
    )

    # 築年 — building construction year (calendar year, not age)
    building_year: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True,
        comment="築年 (construction year). Used to compute building age at display time.",
    )

    # 構造 — building material/structure type
    structure: Mapped[Optional[str]] = mapped_column(
        String(10), nullable=True,
        comment="構造: RC (鉄筋コンクリート) | WOOD (木造) | STEEL (鉄骨) | SRC (鉄骨鉄筋コンクリート)",
    )

    # 階数 — unit floor number (1-based; negative for basement)
    floor_number: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True,
        comment="Unit floor number (1-based). Negative for basement (地下).",
    )

    # 向き — compass orientation
    orientation: Mapped[Optional[str]] = mapped_column(
        String(2), nullable=True,
        comment="向き (compass orientation): N/NE/E/SE/S/SW/W/NW",
    )

    # 入居可能日 — earliest available move-in date
    available_from: Mapped[Optional[date]] = mapped_column(
        Date, nullable=True,
        comment="入居可能日. None = currently occupied; confirm with agent.",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )
