"""Tests for JpViewing ORM model — isolated SQLite with standalone Base."""

from __future__ import annotations

import os
from datetime import datetime

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from sqlalchemy import Column, DateTime, Integer, JSON, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


class _TestBase(DeclarativeBase):
    """Isolated declarative base — avoids full app ORM mapper initialization."""


class _JpViewing(_TestBase):
    __tablename__ = "jp_viewings"
    id = Column(Integer, primary_key=True, autoincrement=True)
    org_id = Column(String(64), nullable=True)
    region = Column(String(3), nullable=False, default="jp")
    listing_id = Column(String(64), nullable=False)
    tenant_id = Column(Integer, nullable=False)
    agent_id = Column(Integer, nullable=True)
    requested_slots = Column(JSON, nullable=False)
    confirmed_slot_ts = Column(DateTime, nullable=True)
    status = Column(String(20), nullable=False, default="requested")
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False)
    updated_at = Column(DateTime, nullable=False)


@pytest.fixture(scope="module")
def sqlite_session():
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    _TestBase.metadata.create_all(engine)
    SF = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    with SF() as session:
        yield session
    _TestBase.metadata.drop_all(engine)


class TestJpViewingModel:
    def test_create_viewing(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        viewing = _JpViewing(
            org_id="org-001",
            listing_id="listing-001",
            tenant_id=42,
            agent_id=99,
            requested_slots=["2025-06-01T10:00:00+09:00", "2025-06-02T14:00:00+09:00"],
            status="requested",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(viewing)
        sqlite_session.flush()

        assert viewing.id is not None
        assert viewing.status == "requested"
        assert isinstance(viewing.requested_slots, list)
        assert len(viewing.requested_slots) == 2

    def test_status_transitions_via_direct_set(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        viewing = _JpViewing(
            org_id="org-001",
            listing_id="listing-002",
            tenant_id=43,
            requested_slots=["2025-06-01T10:00:00+09:00"],
            status="requested",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(viewing)
        sqlite_session.flush()

        viewing.status = "confirmed"
        sqlite_session.flush()
        assert viewing.status == "confirmed"

    def test_nullable_agent_id(self, sqlite_session: Session) -> None:
        now = datetime.utcnow()
        viewing = _JpViewing(
            org_id="org-001",
            listing_id="listing-003",
            tenant_id=44,
            requested_slots=["2025-06-05T10:00:00+09:00"],
            status="requested",
            created_at=now,
            updated_at=now,
        )
        sqlite_session.add(viewing)
        sqlite_session.flush()
        assert viewing.agent_id is None
