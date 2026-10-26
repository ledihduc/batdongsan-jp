"""Tests for JP listing domain models — SQLAlchemy 2.0 in-memory SQLite.

Uses a standalone SQLAlchemy Base to avoid triggering the full app ORM mapper
configuration (which requires all relationships including User model).
"""

from __future__ import annotations

import os
from datetime import date, datetime
from decimal import Decimal

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from sqlalchemy import (
    Boolean, Column, Date, DateTime, ForeignKey, Integer, JSON,
    Numeric, String, Text, create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Session, relationship, sessionmaker, mapped_column, Mapped
from typing import Optional, Any


class _TestBase(DeclarativeBase):
    """Isolated declarative base for JP model SQLite tests.

    Using a separate base avoids the full app ORM mapper initialization
    which would require all models (including User) to be loaded.
    """


# ── Minimal mirrored models (same columns, no cross-app relationships) ─────────

class _JpRentalTerms(_TestBase):
    __tablename__ = "jp_rental_terms"
    id = Column(Integer, primary_key=True, autoincrement=True)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    monthly_rent_jpy = Column(Numeric(12, 0), nullable=False)
    management_fee_jpy = Column(Numeric(10, 0), nullable=True)
    shikikin_months = Column(Numeric(4, 2), nullable=True)
    reikin_months = Column(Numeric(4, 2), nullable=True)
    hoshou_months = Column(Numeric(4, 2), nullable=True)
    koushinryo_months = Column(Numeric(4, 2), nullable=True)
    brokerage_rate = Column(Numeric(5, 4), nullable=True)
    hoshou_fee_jpy = Column(Numeric(10, 0), nullable=True)
    tax_treatment = Column(String(20), nullable=False, default="included")
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


class _JpPropertyInfo(_TestBase):
    __tablename__ = "jp_property_info"
    id = Column(Integer, primary_key=True, autoincrement=True)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    layout = Column(String(10), nullable=True)
    floor_area_sqm = Column(Numeric(7, 2), nullable=True)
    building_year = Column(Integer, nullable=True)
    structure = Column(String(10), nullable=True)
    floor_number = Column(Integer, nullable=True)
    orientation = Column(String(2), nullable=True)
    available_from = Column(Date, nullable=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


class _TrainLine(_TestBase):
    __tablename__ = "jp_train_lines"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name_ja = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=True)
    operator = Column(String(100), nullable=True)
    ekidata_line_cd = Column(Integer, nullable=True, unique=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


class _Station(_TestBase):
    __tablename__ = "jp_stations"
    id = Column(Integer, primary_key=True, autoincrement=True)
    line_id = Column(Integer, ForeignKey("jp_train_lines.id"), nullable=True)
    name_ja = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=True)
    prefecture = Column(String(20), nullable=True)
    latitude = Column(Numeric(10, 7), nullable=True)
    longitude = Column(Numeric(10, 7), nullable=True)
    ekidata_station_cd = Column(Integer, nullable=True, unique=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


class _TransitAccess(_TestBase):
    __tablename__ = "jp_transit_access"
    id = Column(Integer, primary_key=True, autoincrement=True)
    listing_id = Column(String(64), nullable=False)
    station_id = Column(Integer, ForeignKey("jp_stations.id"), nullable=False)
    walk_min = Column(Integer, nullable=False)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


@pytest.fixture(scope="module")
def sqlite_session():
    """In-memory SQLite session using isolated _TestBase."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    _TestBase.metadata.create_all(engine)
    SF = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    with SF() as session:
        yield session
    _TestBase.metadata.drop_all(engine)


class TestJpRentalTermsModel:
    def test_create_and_read(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        terms = _JpRentalTerms(
            org_id="org-001",
            monthly_rent_jpy=Decimal("120000"),
            management_fee_jpy=Decimal("5000"),
            shikikin_months=Decimal("2.0"),
            reikin_months=Decimal("1.0"),
            tax_treatment="included",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(terms)
        sqlite_session.flush()

        assert terms.id is not None
        assert terms.org_id == "org-001"
        assert terms.monthly_rent_jpy == Decimal("120000")
        assert terms.region == "jp"

    def test_nullable_fields_optional(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        terms = _JpRentalTerms(
            org_id="org-002",
            monthly_rent_jpy=Decimal("80000"),
            tax_treatment="included",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(terms)
        sqlite_session.flush()
        assert terms.shikikin_months is None
        assert terms.reikin_months is None
        assert terms.management_fee_jpy is None


class TestJpPropertyInfoModel:
    def test_create_and_read(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        info = _JpPropertyInfo(
            org_id="org-001",
            layout="1LDK",
            floor_area_sqm=Decimal("35.5"),
            building_year=2010,
            structure="RC",
            floor_number=3,
            orientation="S",
            available_from=date(2025, 4, 1),
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(info)
        sqlite_session.flush()

        assert info.id is not None
        assert info.layout == "1LDK"
        assert info.structure == "RC"
        assert info.available_from == date(2025, 4, 1)

    def test_all_optional(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        info = _JpPropertyInfo(org_id=None, created_at=now, updated_at=now)
        sqlite_session.add(info)
        sqlite_session.flush()
        assert info.id is not None
        assert info.layout is None


class TestTransitModels:
    def test_train_line_create(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        line = _TrainLine(
            name_ja="山手線",
            name_en="Yamanote Line",
            operator="JR東日本",
            ekidata_line_cd=11302,
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(line)
        sqlite_session.flush()
        assert line.id is not None
        assert line.name_ja == "山手線"

    def test_station_create(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        line = _TrainLine(
            name_ja="中央線",
            ekidata_line_cd=99901,
            created_at=now, updated_at=now,
        )
        sqlite_session.add(line)
        sqlite_session.flush()

        station = _Station(
            line_id=line.id,
            name_ja="新宿",
            name_en="Shinjuku",
            prefecture="東京都",
            latitude=Decimal("35.6896"),
            longitude=Decimal("139.7006"),
            ekidata_station_cd=9990101,
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(station)
        sqlite_session.flush()
        assert station.id is not None
        assert station.name_ja == "新宿"

    def test_transit_access_create(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        line = _TrainLine(name_ja="テスト線", ekidata_line_cd=88801, created_at=now, updated_at=now)
        sqlite_session.add(line)
        sqlite_session.flush()

        station = _Station(
            line_id=line.id, name_ja="テスト駅",
            ekidata_station_cd=8880101, created_at=now, updated_at=now,
        )
        sqlite_session.add(station)
        sqlite_session.flush()

        access = _TransitAccess(
            listing_id="listing-uuid-001",
            station_id=station.id,
            walk_min=8,
            org_id="org-001",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(access)
        sqlite_session.flush()
        assert access.id is not None
        assert access.walk_min == 8
        assert access.listing_id == "listing-uuid-001"
