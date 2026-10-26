"""SQLAlchemy 2.0 declarative model for Japanese address records.

Table: jp_addresses
Mirrors the 日本郵便 zipcloud API response structure plus kana mirror fields.
All postal code lookups are stored here for caching / audit.

Fields mirror zipcloud API:
  - postal_code:   7-digit postal code (stored without hyphen, e.g. '1500001')
  - prefecture:    都道府県 (e.g. '東京都')
  - city:          市区町村 (e.g. '渋谷区')
  - town:          町域 (e.g. '神南')
  - chome:         丁目 (may be None if granularity not available)
  - banchi:        番地
  - go:            号
  - building:      建物名
  - prefecture_kana, city_kana, town_kana: フリガナ equivalents

Design notes:
- Do NOT add JP columns to app/models.py (god file) — this domain model owns the table.
- Managed by alembic migration 0141_jp_address.py (additive, nullable, idempotent).
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class JpAddress(Base):
    """Japanese postal address record.

    Populated from 日本郵便 zipcloud API lookups and stored for reference.
    Multiple records may share the same postal_code (town-level granularity).
    """

    __tablename__ = "jp_addresses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)

    # 7-digit postal code without hyphen (normalized on insert)
    postal_code: Mapped[str] = mapped_column(String(7), nullable=False, index=True)

    # 都道府県 (prefecture) — e.g. '東京都'
    prefecture: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # 市区町村 (city/ward) — e.g. '渋谷区'
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    # 町域 (town/neighborhood) — e.g. '神南'
    town: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # 丁目 (chome) — optional sub-division within town
    chome: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # 番地 (banchi) — lot number
    banchi: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # 号 (go) — sub-lot number
    go: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)
    # 建物名 (building name)
    building: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)

    # フリガナ (kana phonetic) mirror fields
    prefecture_kana: Mapped[Optional[str]] = mapped_column(String(30), nullable=True)
    city_kana: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)
    town_kana: Mapped[Optional[str]] = mapped_column(String(150), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc
    )
