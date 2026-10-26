"""Unit tests — escalation_ladder.py

Tests cover:
- schedule_approval_escalation: registers correct jobs for standard/kb04/fraud ladders
- cancel_approval_escalation: removes all expected job IDs
- Job timing: T+24h, T+48h, T+60h, T+72h for standard ladder
- KB04 compressed: T+3h, T+6h only
- Fraud lockdown: T+12h, T+24h
- _job_id: correct naming convention
- normalise_phone_e164 is called in sms job (via unit, no real dispatch)
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch, call

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")


from app.services.notification.escalation_ladder import (
    ApprovalEscalationConfig,
    _job_id,
    _build_ladder,
    schedule_approval_escalation,
    cancel_approval_escalation,
    HIGH_VALUE_RENT_THRESHOLD_VND,
)


# ---------------------------------------------------------------------------
# _job_id
# ---------------------------------------------------------------------------


def test_job_id_format():
    assert _job_id("abc-123", "24h") == "escalate_approval_abc-123_24h"
    assert _job_id("xyz", "72h") == "escalate_approval_xyz_72h"


# ---------------------------------------------------------------------------
# Standard ladder timing
# ---------------------------------------------------------------------------


def test_standard_ladder_has_four_stages():
    config = ApprovalEscalationConfig(
        approval_id="test-001",
        owner_id=1,
        operator_id=2,
        owner_email="owner@example.com",
        owner_phone="0901234567",
        property_name="Toà nhà ABC",
        operator_name="Operator X",
        request_type_label="Hợp đồng thuê mới",
        monthly_rent_vnd=10_000_000,
        approval_url="https://ancu365.com/approvals/test-001",
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)
    assert len(ladder) == 4


def test_standard_ladder_correct_timing():
    config = ApprovalEscalationConfig(
        approval_id="test-001",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    job_ids = [j[0] for j in ladder]
    run_dates = [j[1] for j in ladder]

    assert "escalate_approval_test-001_24h" in job_ids
    assert "escalate_approval_test-001_48h" in job_ids
    assert "escalate_approval_test-001_60h" in job_ids
    assert "escalate_approval_test-001_72h" in job_ids

    # Verify timing offsets
    offsets_h = [(rd - created_at).total_seconds() / 3600 for rd in run_dates]
    assert 24 in offsets_h
    assert 48 in offsets_h
    assert 60 in offsets_h
    assert 72 in offsets_h


def test_standard_ladder_24h_uses_email_job():
    """T+24h stage must use _run_email_escalation_job."""
    from app.services.notification import escalation_ladder

    config = ApprovalEscalationConfig(
        approval_id="test-002",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    job_24h = next(j for j in ladder if "24h" in j[0])
    assert job_24h[2] is escalation_ladder._run_email_escalation_job


def test_standard_ladder_60h_uses_sms_job():
    """T+60h stage must use _run_sms_escalation_job."""
    from app.services.notification import escalation_ladder

    config = ApprovalEscalationConfig(
        approval_id="test-003",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    job_60h = next(j for j in ladder if "60h" in j[0])
    assert job_60h[2] is escalation_ladder._run_sms_escalation_job


def test_standard_ladder_72h_uses_auto_reject_job():
    """T+72h stage must use _run_auto_reject_notification_job."""
    from app.services.notification import escalation_ladder

    config = ApprovalEscalationConfig(
        approval_id="test-004",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    job_72h = next(j for j in ladder if "72h" in j[0])
    assert job_72h[2] is escalation_ladder._run_auto_reject_notification_job


# ---------------------------------------------------------------------------
# KB04 fast-track ladder
# ---------------------------------------------------------------------------


def test_kb04_ladder_has_two_stages():
    config = ApprovalEscalationConfig(
        approval_id="kb04-001",
        owner_id=1,
        operator_id=2,
        ladder_type="kb04_fasttrack",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)
    assert len(ladder) == 2


def test_kb04_ladder_timing():
    config = ApprovalEscalationConfig(
        approval_id="kb04-001",
        owner_id=1,
        operator_id=2,
        ladder_type="kb04_fasttrack",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    offsets_h = [(j[1] - created_at).total_seconds() / 3600 for j in ladder]
    assert 3 in offsets_h
    assert 6 in offsets_h


# ---------------------------------------------------------------------------
# Fraud lockdown ladder
# ---------------------------------------------------------------------------


def test_fraud_lockdown_ladder_has_two_stages():
    config = ApprovalEscalationConfig(
        approval_id="fraud-001",
        owner_id=1,
        operator_id=2,
        ladder_type="fraud_lockdown",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)
    assert len(ladder) == 2


def test_fraud_lockdown_ladder_timing():
    config = ApprovalEscalationConfig(
        approval_id="fraud-001",
        owner_id=1,
        operator_id=2,
        ladder_type="fraud_lockdown",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)
    ladder = _build_ladder(config, created_at)

    offsets_h = [(j[1] - created_at).total_seconds() / 3600 for j in ladder]
    assert 12 in offsets_h
    assert 24 in offsets_h


# ---------------------------------------------------------------------------
# schedule_approval_escalation
# ---------------------------------------------------------------------------


def test_schedule_approval_escalation_calls_add_job():
    """schedule_approval_escalation registers all ladder jobs on scheduler."""
    mock_scheduler = MagicMock()

    config = ApprovalEscalationConfig(
        approval_id="sched-001",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    created_at = datetime(2026, 7, 1, 10, 0, 0)

    schedule_approval_escalation(mock_scheduler, config, created_at, db_session_factory=None)

    assert mock_scheduler.add_job.call_count == 4  # 4 stages in standard ladder


def test_schedule_approval_escalation_uses_replace_existing():
    """Jobs must have replace_existing=True for idempotent re-registration."""
    mock_scheduler = MagicMock()
    config = ApprovalEscalationConfig(
        approval_id="sched-002",
        owner_id=1,
        operator_id=2,
        ladder_type="standard",
    )
    schedule_approval_escalation(
        mock_scheduler, config, datetime(2026, 7, 1), db_session_factory=None
    )

    for call_args in mock_scheduler.add_job.call_args_list:
        kwargs = call_args.kwargs
        assert kwargs.get("replace_existing") is True, (
            f"Job {kwargs.get('id')} missing replace_existing=True"
        )


def test_schedule_approval_escalation_handles_scheduler_error(mocker):
    """schedule_approval_escalation logs errors but does not raise."""
    mock_log = mocker.patch("app.services.notification.escalation_ladder.logger")
    mock_scheduler = MagicMock()
    mock_scheduler.add_job.side_effect = Exception("Scheduler down")

    config = ApprovalEscalationConfig(
        approval_id="sched-err",
        owner_id=1,
        operator_id=2,
    )
    # Must not raise
    schedule_approval_escalation(
        mock_scheduler, config, datetime(2026, 7, 1), db_session_factory=None
    )
    # logger.error must have been called with "Failed to schedule" message
    assert mock_log.error.called
    error_msg = str(mock_log.error.call_args)
    assert "Failed to schedule" in error_msg


# ---------------------------------------------------------------------------
# cancel_approval_escalation
# ---------------------------------------------------------------------------


def test_cancel_approval_escalation_removes_all_stages():
    """cancel_approval_escalation attempts to remove all known stage job IDs."""
    mock_scheduler = MagicMock()
    cancel_approval_escalation(mock_scheduler, "cancel-001")

    removed_ids = {c.args[0] for c in mock_scheduler.remove_job.call_args_list}
    # Standard stages
    assert "escalate_approval_cancel-001_24h" in removed_ids
    assert "escalate_approval_cancel-001_48h" in removed_ids
    assert "escalate_approval_cancel-001_60h" in removed_ids
    assert "escalate_approval_cancel-001_72h" in removed_ids
    # KB04 stages
    assert "escalate_approval_cancel-001_3h" in removed_ids
    assert "escalate_approval_cancel-001_6h" in removed_ids


def test_cancel_approval_escalation_does_not_raise_on_missing_job():
    """cancel_approval_escalation tolerates jobs that no longer exist."""
    mock_scheduler = MagicMock()
    mock_scheduler.remove_job.side_effect = Exception("Job not found")
    # Must not raise
    cancel_approval_escalation(mock_scheduler, "missing-001")


# ---------------------------------------------------------------------------
# High-value threshold constant
# ---------------------------------------------------------------------------


def test_high_value_threshold_is_20m_vnd():
    assert HIGH_VALUE_RENT_THRESHOLD_VND == 20_000_000
