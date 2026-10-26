"""SQLAlchemy 2.0 models for JP train station reference data and transit access.

Tables:
  jp_train_lines     — canonical train line catalog (駅データ.jp source)
  jp_stations        — individual station records
  jp_transit_access  — listing <-> station walk-time association

Data lifecycle:
  - jp_train_lines and jp_stations are populated by scripts/import_jp_stations.py
    from 駅データ.jp CSV export. Refresh is quarterly, not real-time.
  - jp_transit_access is populated by agents when creating/editing listings.

Design decisions:
- Managed by migration 0145_jp_transit (additive, nullable, idempotent).
- listing_id stored as string (no FK) to avoid cross-module dep on core listing.
- org_id on TransitAccess for multi-tenant isolation (transit_access is agent-entered).
- TrainLine and Station have no org_id — they are shared reference data.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def _now_utc() -> datetime:
    return datetime.utcnow()


class TrainLine(Base):
    """JP train line reference record.

    Populated from 駅データ.jp CSV import. ekidata_line_cd is the stable external key
    used to detect duplicates on quarterly refresh.
    """

    __tablename__ = "jp_train_lines"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # 路線名 in Japanese (e.g. '山手線', '東京メトロ銀座線')
    name_ja: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True,
        comment="路線名 in Japanese",
    )

    # Romanized name (e.g. 'Yamanote Line')
    name_en: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True,
        comment="Romanized line name for display",
    )

    # 鉄道会社 (operator) — e.g. 'JR東日本', '東京メトロ'
    operator: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True,
        comment="鉄道会社 operator name",
    )

    # External reference from 駅データ.jp CSV (line_cd column)
    ekidata_line_cd: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, unique=True, index=True,
        comment="駅データ.jp line_cd. Used for idempotent quarterly refresh.",
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )

    # Relationship to stations on this line
    stations: Mapped[list["Station"]] = relationship(
        "Station", back_populates="line", lazy="select",
    )


class Station(Base):
    """JP train station reference record.

    Each station belongs to one primary line (line_id). A station that exists on
    multiple lines (e.g. 渋谷 on Yamanote + Ginza lines) has multiple rows —
    one per (station, line) combination — matching 駅データ.jp's data model.

    ekidata_station_cd is the stable external key for quarterly refresh idempotency.
    """

    __tablename__ = "jp_stations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # FK to primary line
    line_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("jp_train_lines.id"), nullable=True, index=True,
    )

    # 駅名 in Japanese (e.g. '渋谷', '新宿')
    name_ja: Mapped[str] = mapped_column(
        String(100), nullable=False, index=True,
        comment="駅名 in Japanese",
    )

    # Romanized station name (e.g. 'Shibuya')
    name_en: Mapped[Optional[str]] = mapped_column(
        String(100), nullable=True,
        comment="Romanized station name",
    )

    # 都道府県 for regional filtering
    prefecture: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True, index=True,
        comment="都道府県 (e.g. '東京都')",
    )

    # Geographic coordinates (for future map display)
    latitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 7), nullable=True)
    longitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 7), nullable=True)

    # External reference from 駅データ.jp CSV (station_cd column)
    ekidata_station_cd: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True, unique=True, index=True,
        comment="駅データ.jp station_cd. Used for idempotent quarterly refresh.",
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )

    # Relationship back to parent line
    line: Mapped[Optional[TrainLine]] = relationship(
        "TrainLine", back_populates="stations", lazy="select",
    )

    # Relationship to transit access records
    transit_accesses: Mapped[list["TransitAccess"]] = relationship(
        "TransitAccess", back_populates="station", lazy="select",
    )


class TransitAccess(Base):
    """Association between a listing and a nearby train station with walk time.

    A listing may have multiple transit_access records (different stations/lines).
    org_id is mandatory for multi-tenant isolation — all list queries must filter by it.

    Org scoping:
        Every repository list query filtering this model MUST include:
            .filter(TransitAccess.org_id == org_id)  # MULTI-TENANT ISOLATION
    """

    __tablename__ = "jp_transit_access"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Listing reference — stored as string UUID, no FK to avoid cross-module dep.
    listing_id: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True,
        comment="Listing UUID (no FK to avoid cross-schema dependency on core)",
    )

    # FK to jp_stations
    station_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("jp_stations.id"), nullable=False,
    )

    # 徒歩分数 — walk time in minutes (max 60 per business rule)
    walk_min: Mapped[int] = mapped_column(
        Integer, nullable=False,
        comment="徒歩分数 (walk minutes) from listing to station. Max 60.",
    )

    # Multi-tenant broker org isolation
    org_id: Mapped[Optional[str]] = mapped_column(
        String(64), nullable=True, index=True,
        comment="Broker org tenant ID. MUST be filtered in every list query.",
    )
    region: Mapped[str] = mapped_column(
        String(3), nullable=False, default="jp",
        comment="Defense-in-depth region tag. Always 'jp'.",
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=_now_utc)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, default=_now_utc, onupdate=_now_utc,
    )

    # Relationship to station
    station: Mapped[Station] = relationship(
        "Station", back_populates="transit_accesses", lazy="select",
    )
