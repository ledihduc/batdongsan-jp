"""Unit tests for ExecutorExceptionService — AC-58d (gate O3)."""

from __future__ import annotations

import os

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

import app.models  # noqa: F401 — register User on Base.metadata

from app.services.owner_death.executor_exception_service import (
    ExecutorExceptionDisabledError,
    ExecutorExceptionService,
    ExecutorNotAuthorizedError,
    is_executor_exception_enabled,
)


# ---------------------------------------------------------------------------
# Feature flag tests
# ---------------------------------------------------------------------------


class TestFeatureFlag:
    def test_disabled_by_default(self, monkeypatch):
        monkeypatch.delenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", raising=False)
        assert is_executor_exception_enabled() is False

    def test_enabled_when_set_to_true(self, monkeypatch):
        monkeypatch.setenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", "true")
        assert is_executor_exception_enabled() is True

    def test_enabled_when_set_to_1(self, monkeypatch):
        monkeypatch.setenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", "1")
        assert is_executor_exception_enabled() is True

    def test_disabled_when_set_to_false(self, monkeypatch):
        monkeypatch.setenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", "false")
        assert is_executor_exception_enabled() is False

    def test_disabled_when_empty(self, monkeypatch):
        monkeypatch.setenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", "")
        assert is_executor_exception_enabled() is False


# ---------------------------------------------------------------------------
# check_enabled
# ---------------------------------------------------------------------------


class TestCheckEnabled:
    def test_raises_when_disabled(self, monkeypatch):
        monkeypatch.delenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", raising=False)
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        with pytest.raises(ExecutorExceptionDisabledError, match="gate O3"):
            svc.check_enabled()

    def test_does_not_raise_when_enabled(self, monkeypatch):
        monkeypatch.setenv("OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED", "true")
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        # Should not raise
        svc.check_enabled()


# ---------------------------------------------------------------------------
# validate_executor
# ---------------------------------------------------------------------------


class TestValidateExecutor:
    def test_matching_executor_passes(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)
        # Should not raise
        svc.validate_executor(executor_user_id=42, cert_executor_user_id=42)

    def test_no_executor_designated_raises(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        with pytest.raises(ExecutorNotAuthorizedError, match="No executor"):
            svc.validate_executor(executor_user_id=42, cert_executor_user_id=None)

    def test_wrong_executor_raises(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        with pytest.raises(ExecutorNotAuthorizedError, match="not the designated executor"):
            svc.validate_executor(executor_user_id=99, cert_executor_user_id=42)


# ---------------------------------------------------------------------------
# record_executor_decision
# ---------------------------------------------------------------------------


class TestRecordExecutorDecision:
    def test_approved_decision_recorded(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        result = svc.record_executor_decision(
            approval_id="approval-uuid-001",
            executor_user_id=42,
            decision="approved",
            cert_id="cert-uuid-123",
            notes="Urgent rent collection",
        )

        assert result["executor_override"] is True
        assert result["decision_by_executor"] is True
        assert result["decision"] == "approved"
        assert result["executor_user_id"] == 42
        assert result["approval_id"] == "approval-uuid-001"
        assert result["death_cert_id"] == "cert-uuid-123"

    def test_rejected_decision_recorded(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        result = svc.record_executor_decision(
            approval_id="approval-uuid-002",
            executor_user_id=42,
            decision="rejected",
            cert_id="cert-uuid-123",
        )

        assert result["decision"] == "rejected"
        assert result["notes"] is None

    def test_invalid_decision_raises(self):
        db = MagicMock()
        svc = ExecutorExceptionService(db)

        with pytest.raises(ValueError, match="Invalid decision"):
            svc.record_executor_decision(
                approval_id="approval-uuid-001",
                executor_user_id=42,
                decision="pending",  # invalid
                cert_id="cert-uuid-123",
            )


# ---------------------------------------------------------------------------
# list_eligible_approvals — table may not exist
# ---------------------------------------------------------------------------


class TestListEligibleApprovals:
    def test_returns_empty_when_table_missing(self):
        db = MagicMock()
        # Simulate query failure (delegation_approvals table not yet created)
        db.execute.side_effect = Exception("relation does not exist")
        svc = ExecutorExceptionService(db)

        result = svc.list_eligible_approvals(
            owner_user_id=10,
            cert_verified_at=datetime(2026, 1, 1, 12, 0, 0),
        )
        assert result == []
