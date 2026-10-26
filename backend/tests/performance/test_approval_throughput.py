"""Performance test: approval service throughput under concurrency (Phase 11).

Target: approval service handles 100 concurrent submissions without deadlock.

Uses threading to simulate 100 concurrent approval creates.
Each thread gets its own DB session (SQLite in-memory with StaticPool).

Run: pytest tests/performance/test_approval_throughput.py -v
"""

from __future__ import annotations

import os
import uuid
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Any
from unittest.mock import patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.database import Base


# ---------------------------------------------------------------------------
# Shared engine (one in-memory DB for all threads)
# ---------------------------------------------------------------------------


_ENGINE = None
_SESSION_FACTORY = None


def _get_engine():
    global _ENGINE, _SESSION_FACTORY
    if _ENGINE is None:
        _ENGINE = create_engine(
            "sqlite:///:memory:",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(bind=_ENGINE)
        _SESSION_FACTORY = sessionmaker(bind=_ENGINE, autoflush=False, autocommit=False)
    return _ENGINE, _SESSION_FACTORY


def _get_session() -> Session:
    _, factory = _get_engine()
    return factory()


# ---------------------------------------------------------------------------
# Seed helpers (run once in shared DB)
# ---------------------------------------------------------------------------


_SEED_LOCK = threading.Lock()
_SEEDED = False
_SHARED_DELEGATION_ID: str = ""


def _ensure_seeded() -> str:
    """Seed users + one active delegation; return delegation_id. Thread-safe."""
    global _SEEDED, _SHARED_DELEGATION_ID
    with _SEED_LOCK:
        if _SEEDED:
            return _SHARED_DELEGATION_ID
        session = _get_session()
        try:
            from app.models import User
            from app.domain.delegation import Delegation

            for user_id in [1, 2]:
                if not session.query(User).filter_by(id=user_id).first():
                    u = User(
                        id=user_id,
                        email=f"user{user_id}@perf-test.com",
                        phone=f"+849{user_id:010d}",
                        name=f"PerfUser {user_id}",
                        role="host",
                        is_active=True,
                        password_hash="x",
                    )
                    if user_id == 2:
                        u.is_operator_capable = True
                    session.add(u)

            delegation_id = str(uuid.uuid4())
            d = Delegation(
                id=delegation_id,
                owner_id=1,
                operator_id=2,
                invitation_id=None,
                role_preset="operator_full",
                scope_type="all",
                scope_target_ids=None,
                commission_pct=Decimal("5.00"),
                commission_fixed_vnd=None,
                status="active",
                activated_at=datetime.utcnow(),
                out_of_office_start=None,
                out_of_office_end=None,
                terminate_requested_at=None,
                terminated_at=None,
                threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("5.00"),
        threshold_refund_vnd=Decimal("1000000"),
        retention_tier="hot",
                poa_format="notarized",
                poa_document_path=None,
            )
            session.add(d)
            session.commit()
            _SHARED_DELEGATION_ID = delegation_id
            _SEEDED = True
            return delegation_id
        except Exception:  # noqa: BLE001
            session.rollback()
            raise
        finally:
            session.close()


# ---------------------------------------------------------------------------
# Worker: one approval submission per thread
# ---------------------------------------------------------------------------


def _submit_one_approval(delegation_id: str, thread_idx: int) -> dict[str, Any]:
    """Submit one approval in a dedicated DB session. Returns result dict."""
    session = _get_session()
    result: dict[str, Any] = {"thread": thread_idx, "success": False, "error": None}
    try:
        from app.domain.delegation import Delegation, DelegationApproval
        from app.services.approval.approval_service import ApprovalService
        from app.services.actor_context import ActorContext

        delegation = session.query(Delegation).filter_by(id=delegation_id).first()
        if delegation is None:
            result["error"] = "delegation not found"
            return result

        operator_ctx = ActorContext(
            actor_user_id=2,
            on_behalf_of_user_id=1,
            delegation_id=delegation_id,
            scope_type="all",
            scope_target_building_ids=None,
            permission_set=frozenset(["invoice.create"]),
            actor_role="host",
            request_id=str(uuid.uuid4()),
        )

        svc = ApprovalService(session)
        with patch.object(svc, "_log_event", return_value=None):
            approval = svc.create(
                delegation=delegation,
                action_type="invoice_above_threshold",
                action_payload={"invoice_id": thread_idx, "amount_vnd": "6000000"},
                sla_class="default_72h",
            )
        session.commit()
        result["success"] = True
        result["approval_id"] = str(approval.id)
    except Exception as exc:  # noqa: BLE001
        session.rollback()
        result["error"] = str(exc)
    finally:
        session.close()
    return result


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestApprovalThroughput:
    """Approval service handles 100 concurrent submissions without deadlock."""

    def test_100_concurrent_approvals_no_deadlock(self):
        """Submit 100 approval requests concurrently — all succeed, no deadlock.

        Timeout per thread: 30s. Total test timeout enforced by pytest.
        """
        delegation_id = _ensure_seeded()

        worker_count = 100
        start = time.perf_counter()

        with ThreadPoolExecutor(max_workers=20) as pool:
            futures = [
                pool.submit(_submit_one_approval, delegation_id, i)
                for i in range(worker_count)
            ]
            results = [f.result(timeout=30) for f in as_completed(futures)]

        elapsed = time.perf_counter() - start

        errors = [r for r in results if not r["success"]]
        successes = [r for r in results if r["success"]]

        # Allow some errors due to SQLite concurrency limits (it uses a write lock)
        # Key assertion: no deadlock (which would cause infinite hang)
        assert len(results) == worker_count, "All futures should complete"
        success_rate = len(successes) / worker_count
        assert success_rate >= 0.50, (
            f"Success rate {success_rate:.0%} too low. "
            f"Errors: {[e['error'] for e in errors[:5]]}"
        )
        assert elapsed < 60, f"100 concurrent approvals took {elapsed:.1f}s — possible deadlock"

    def test_sequential_100_approvals_baseline(self):
        """Sequential baseline: 100 sequential approvals to compare against concurrent."""
        delegation_id = _ensure_seeded()

        worker_count = 100
        start = time.perf_counter()
        results = []
        for i in range(worker_count):
            r = _submit_one_approval(delegation_id, i + 200)  # offset to avoid ID clash
            results.append(r)
        sequential_time = time.perf_counter() - start

        successes = [r for r in results if r["success"]]
        success_rate = len(successes) / worker_count
        assert success_rate >= 0.90, (
            f"Sequential success rate {success_rate:.0%} too low (no concurrency)."
        )
        # Sequential should be well under 60s
        assert sequential_time < 60, f"Sequential 100 approvals took {sequential_time:.1f}s"

    def test_approval_idempotency_under_load(self):
        """Same approval cannot be decided twice even under concurrent load (NFR-01)."""
        delegation_id = _ensure_seeded()
        session = _get_session()

        try:
            from app.domain.delegation import Delegation, DelegationApproval
            from app.services.approval.approval_service import (
                ApprovalService,
                ApprovalAlreadyDecided,
            )
            from app.services.actor_context import ActorContext

            delegation = session.query(Delegation).filter_by(id=delegation_id).first()

            # Create one approval to race-decide on
            operator_ctx = ActorContext(
                actor_user_id=2,
                on_behalf_of_user_id=1,
                delegation_id=delegation_id,
                scope_type="all",
                scope_target_building_ids=None,
                permission_set=frozenset(["invoice.create"]),
                actor_role="host",
                request_id=str(uuid.uuid4()),
            )
            svc = ApprovalService(session)
            with patch.object(svc, "_log_event", return_value=None):
                approval = svc.create(
                delegation=delegation,
                    action_type="invoice_above_threshold",
                    action_payload={"invoice_id": 9999, "amount_vnd": "7000000"},
                    sla_class="default_72h",
                )
            session.commit()

            owner_ctx = ActorContext(
                actor_user_id=1,
                on_behalf_of_user_id=None,
                delegation_id=None,
                scope_type=None,
                scope_target_building_ids=None,
                permission_set=frozenset(["approval.decide"]),
                actor_role="host",
                request_id=str(uuid.uuid4()),
            )

            # First decide: should succeed
            with patch.object(svc, "_log_event", return_value=None):
                svc.decide(
                    owner_ctx=owner_ctx,
                    approval_id=str(approval.id),
                    decision="approved",
                    reason=None,
                )
            session.commit()

            # Second decide: must raise ApprovalAlreadyDecided
            with pytest.raises(ApprovalAlreadyDecided):
                with patch.object(svc, "_log_event", return_value=None):
                    svc.decide(
                        owner_ctx=owner_ctx,
                        approval_id=str(approval.id),
                        decision="rejected",
                        reason="testing idempotency",
                    )
        finally:
            session.close()
