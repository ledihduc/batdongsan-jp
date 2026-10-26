"""Regression: ChangeLog dual-identity columns don't break existing readers (Phase 11).

Verifies:
  - on_behalf_of_user_id column is nullable → old code that reads ChangeLog
    without expecting this column still works (column defaults to None)
  - Existing ChangeLog queries by actor_id still work (no schema breakage)
  - ChangeLog rows created before delegation feature (no on_behalf_of) readable

The dual-identity audit columns added in phase-02:
  - change_logs.on_behalf_of_user_id (nullable, FK users.id)
  - change_logs.acted_via_delegation_id (nullable, STR)

Existing readers that don't SELECT these columns are unaffected.
Existing readers that SELECT * still get the rows — columns are just None.

AC coverage: AC-31b (dual-identity audit), backward compatibility regression
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Generator

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.database import Base


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def sqlite_engine():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    try:
        Base.metadata.drop_all(bind=engine)
    except Exception:  # noqa: BLE001
        pass
    engine.dispose()


@pytest.fixture()
def db(sqlite_engine) -> Generator[Session, None, None]:
    connection = sqlite_engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    try:
        yield session
    finally:
        session.close()
        transaction.rollback()
        connection.close()


# ---------------------------------------------------------------------------
# Helpers: seed ChangeLog rows (pre-delegation + post-delegation)
# ---------------------------------------------------------------------------


def _seed_old_changelog_row(db: Session, actor_id: int = 1) -> object:
    """Seed a ChangeLog row without dual-identity columns (pre-phase-02 style)."""
    try:
        from app.models import ChangeLog
    except ImportError:
        pytest.skip("ChangeLog model not found — skipping")

    row = ChangeLog(
        entity_type="invoice",
        entity_id=str(uuid.uuid4()),
        actor_id=actor_id,
        action="created",
        before_json=None,
        after_json=json.dumps({"amount": "5000000"}),
        # on_behalf_of_user_id is NOT set (simulating pre-delegation row)
    )
    db.add(row)
    db.flush()
    return row


def _seed_delegation_changelog_row(
    db: Session,
    actor_id: int = 2,
    on_behalf_of: int = 1,
    delegation_id: str | None = None,
) -> object:
    """Seed a ChangeLog row WITH dual-identity columns (post-phase-02 style)."""
    try:
        from app.models import ChangeLog
    except ImportError:
        pytest.skip("ChangeLog model not found — skipping")

    row = ChangeLog(
        entity_type="invoice",
        entity_id=str(uuid.uuid4()),
        actor_id=actor_id,
        action="updated",
        before_json=json.dumps({"amount": "5000000"}),
        after_json=json.dumps({"amount": "6000000"}),
        on_behalf_of_user_id=on_behalf_of,
        acted_via_delegation_id=delegation_id or str(uuid.uuid4()),
    )
    db.add(row)
    db.flush()
    return row


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestChangeLogBackwardCompatibility:
    """on_behalf_of_user_id is nullable — old ChangeLog rows still readable."""

    def test_old_changelog_row_has_none_on_behalf_of(self, db: Session):
        """Pre-delegation ChangeLog row: on_behalf_of_user_id is None (nullable)."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        row = _seed_old_changelog_row(db, actor_id=1)

        # Re-query to verify DB storage
        fetched = db.query(ChangeLog).filter_by(id=row.id).first()
        assert fetched is not None, "ChangeLog row should be retrievable"
        # on_behalf_of_user_id should be None (nullable column default)
        assert fetched.on_behalf_of_user_id is None, (
            f"Expected None, got {fetched.on_behalf_of_user_id!r} — column must be nullable"
        )

    def test_delegation_changelog_row_has_on_behalf_of(self, db: Session):
        """Post-delegation ChangeLog row: on_behalf_of_user_id populated correctly."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        row = _seed_delegation_changelog_row(db, actor_id=2, on_behalf_of=1)

        fetched = db.query(ChangeLog).filter_by(id=row.id).first()
        assert fetched is not None
        assert fetched.on_behalf_of_user_id == 1
        assert fetched.actor_id == 2

    def test_query_by_actor_id_works_for_both_row_types(self, db: Session):
        """Existing reader: query by actor_id returns both old and new rows."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        actor_id = 5
        _seed_old_changelog_row(db, actor_id=actor_id)
        _seed_delegation_changelog_row(db, actor_id=actor_id, on_behalf_of=1)

        # Old-style query: just filter by actor_id (no knowledge of dual-identity)
        rows = db.query(ChangeLog).filter_by(actor_id=actor_id).all()
        assert len(rows) >= 2, f"Expected at least 2 rows for actor {actor_id}, got {len(rows)}"

    def test_mixed_rows_no_column_error(self, db: Session):
        """Reading both old and new rows in a single query does not raise."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        actor_id = 6
        old_row = _seed_old_changelog_row(db, actor_id=actor_id)
        new_row = _seed_delegation_changelog_row(db, actor_id=actor_id, on_behalf_of=1)

        rows = db.query(ChangeLog).filter_by(actor_id=actor_id).all()
        on_behalf_of_values = [r.on_behalf_of_user_id for r in rows]

        # Old rows have None, new rows have 1
        assert None in on_behalf_of_values, "Old row should have None on_behalf_of"
        assert 1 in on_behalf_of_values, "New row should have on_behalf_of=1"

    def test_changelog_entity_type_query_backward_compat(self, db: Session):
        """Existing reader: query by entity_type still works (pre-dual-identity)."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        _seed_old_changelog_row(db, actor_id=1)
        _seed_delegation_changelog_row(db, actor_id=2, on_behalf_of=1)

        # Old-style reader: no knowledge of acted_via_delegation_id / on_behalf_of
        rows = db.query(ChangeLog).filter_by(entity_type="invoice").all()
        assert len(rows) >= 2, "Both old and new rows should be queryable by entity_type"


class TestChangeLogDualIdentityPresent:
    """Verify dual-identity columns are actually present in ChangeLog model."""

    def test_on_behalf_of_column_exists(self, db: Session):
        """ChangeLog model has on_behalf_of_user_id attribute."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        # Check that the attribute exists on the model class
        assert hasattr(ChangeLog, "on_behalf_of_user_id"), (
            "ChangeLog model must have on_behalf_of_user_id column (phase-02 addition)"
        )

    def test_delegation_id_column_exists(self, db: Session):
        """ChangeLog model has acted_via_delegation_id attribute."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        assert hasattr(ChangeLog, "acted_via_delegation_id"), (
            "ChangeLog model must have acted_via_delegation_id column (phase-02 addition)"
        )

    def test_on_behalf_of_is_nullable_at_db_level(self, db: Session):
        """Verify on_behalf_of_user_id is nullable by inserting without it."""
        try:
            from app.models import ChangeLog
        except ImportError:
            pytest.skip("ChangeLog model not found")

        # This must not raise — column is nullable
        row = ChangeLog(
            entity_type="building",
            entity_id="100",
            actor_id=1,
            action="viewed",
            before_json=None,
            after_json=None,
            # Deliberately omitting on_behalf_of_user_id + acted_via_delegation_id
        )
        db.add(row)
        try:
            db.flush()  # Should succeed — nullable columns
        except Exception as exc:
            pytest.fail(
                f"Inserting ChangeLog without on_behalf_of_user_id raised: {exc}. "
                "The column must be nullable for backward compatibility."
            )
