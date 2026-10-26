"""Tests for JP viewing scheduler — slot validation and state machine.

Uses in-memory state; no DB connection required for scheduler logic tests.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from unittest.mock import MagicMock

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")
os.environ.setdefault("REGION", "jp")

import pytest
from fastapi import HTTPException

from app.services.jp.viewing.scheduler import (
    ViewingSchedulerError,
    cancel_viewing,
    complete_viewing,
    confirm_viewing,
    create_viewing_request,
    validate_slots,
)


def _future_jst_business_slot(*, hours_ahead: int = 48, hour_jst: int = 14) -> str:
    """Build a future ISO timestamp that satisfies all business constraints.

    - hours_ahead: how far in the future (default 48h > 24h lead time)
    - hour_jst: JST hour in business hours (default 14:00 = 2pm)
    """
    jst = timezone(timedelta(hours=9))
    base = datetime.now(tz=jst)
    target = base + timedelta(hours=hours_ahead)
    # Set to target date at the specified JST hour
    slot_dt = target.replace(hour=hour_jst, minute=0, second=0, microsecond=0)
    return slot_dt.isoformat()


def _make_viewing(**kwargs):
    """Create a mock JpViewing object with sensible defaults."""
    viewing = MagicMock()
    viewing.id = kwargs.get("id", 1)
    viewing.org_id = kwargs.get("org_id", "org-001")
    viewing.listing_id = kwargs.get("listing_id", "listing-001")
    viewing.tenant_id = kwargs.get("tenant_id", 42)
    viewing.agent_id = kwargs.get("agent_id", 99)
    viewing.status = kwargs.get("status", "requested")
    viewing.requested_slots = kwargs.get("requested_slots", [_future_jst_business_slot()])
    viewing.confirmed_slot_ts = kwargs.get("confirmed_slot_ts", None)
    viewing.notes = kwargs.get("notes", None)
    return viewing


class TestValidateSlots:
    """Unit tests for the slot validation function."""

    def test_single_valid_slot(self) -> None:
        slot = _future_jst_business_slot()
        parsed = validate_slots([slot])
        assert len(parsed) == 1

    def test_three_valid_slots(self) -> None:
        slots = [_future_jst_business_slot(hours_ahead=48 + i) for i in range(3)]
        parsed = validate_slots(slots)
        assert len(parsed) == 3

    def test_four_slots_rejected(self) -> None:
        """Max 3 slots allowed."""
        slots = [_future_jst_business_slot(hours_ahead=48 + i) for i in range(4)]
        with pytest.raises(ViewingSchedulerError, match="1-3"):
            validate_slots(slots)

    def test_empty_slots_rejected(self) -> None:
        with pytest.raises(ViewingSchedulerError, match="1-3"):
            validate_slots([])

    def test_invalid_timestamp_rejected(self) -> None:
        with pytest.raises(ViewingSchedulerError, match="Invalid slot timestamp"):
            validate_slots(["not-a-date"])

    def test_slot_within_24h_rejected(self) -> None:
        """Slot < 24h in advance must be rejected."""
        jst = timezone(timedelta(hours=9))
        ref = datetime.now(tz=jst)
        # Only 1h ahead — should fail lead time check
        slot = (ref + timedelta(hours=1)).replace(hour=14, minute=0, second=0, microsecond=0)
        with pytest.raises(ViewingSchedulerError, match="less than"):
            validate_slots([slot.isoformat()], reference_time=ref)

    def test_slot_outside_business_hours_rejected(self) -> None:
        """Slot at 9:00 JST (before 10:00) must be rejected."""
        jst = timezone(timedelta(hours=9))
        ref = datetime.now(tz=jst)
        # 48h ahead but at 9:00 JST (before business hours)
        slot = (ref + timedelta(hours=48)).replace(hour=9, minute=0, second=0, microsecond=0)
        with pytest.raises(ViewingSchedulerError, match="outside business hours"):
            validate_slots([slot.isoformat()], reference_time=ref)

    def test_slot_at_10am_jst_accepted(self) -> None:
        """10:00 JST is the business hours boundary — should pass."""
        slot = _future_jst_business_slot(hour_jst=10)
        parsed = validate_slots([slot])
        assert len(parsed) == 1

    def test_slot_at_19_rejected(self) -> None:
        """19:00 JST is exclusive boundary — should fail."""
        slot = _future_jst_business_slot(hour_jst=19)
        with pytest.raises(ViewingSchedulerError, match="outside business hours"):
            validate_slots([slot])

    def test_slot_at_18_accepted(self) -> None:
        """18:00 JST is within business hours."""
        slot = _future_jst_business_slot(hour_jst=18)
        parsed = validate_slots([slot])
        assert len(parsed) == 1


class TestCreateViewingRequest:
    """Tests for create_viewing_request — validation + repo call."""

    def test_creates_viewing_on_valid_slots(self) -> None:
        mock_repo = MagicMock()
        mock_repo.create.return_value = _make_viewing()

        slot = _future_jst_business_slot()
        result = create_viewing_request(
            mock_repo,
            org_id="org-001",
            listing_id="listing-001",
            tenant_id=42,
            requested_slots=[slot],
        )
        mock_repo.create.assert_called_once()
        call_kwargs = mock_repo.create.call_args.kwargs
        assert call_kwargs["listing_id"] == "listing-001"
        assert call_kwargs["tenant_id"] == 42

    def test_raises_422_on_invalid_slots(self) -> None:
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            create_viewing_request(
                mock_repo,
                org_id="org-001",
                listing_id="listing-001",
                tenant_id=42,
                requested_slots=["not-a-date"],
            )
        assert exc_info.value.status_code == 422
        mock_repo.create.assert_not_called()


class TestConfirmViewing:
    """Tests for confirm_viewing state machine."""

    def test_confirm_valid_slot(self) -> None:
        slot = _future_jst_business_slot()
        viewing = _make_viewing(status="requested", requested_slots=[slot])
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = viewing

        confirm_viewing(
            mock_repo,
            viewing=viewing,
            confirmed_slot_ts=slot,
            agent_user_id=99,
            org_id="org-001",
        )
        mock_repo.update_status.assert_called_once()
        call_kwargs = mock_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "confirmed"

    def test_confirm_slot_not_in_requested_raises_422(self) -> None:
        slot = _future_jst_business_slot()
        other_slot = _future_jst_business_slot(hours_ahead=72)
        viewing = _make_viewing(status="requested", requested_slots=[slot])
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            confirm_viewing(
                mock_repo,
                viewing=viewing,
                confirmed_slot_ts=other_slot,  # NOT in requested_slots
                agent_user_id=99,
                org_id="org-001",
            )
        assert exc_info.value.status_code == 422

    def test_confirm_cancelled_viewing_rejected(self) -> None:
        viewing = _make_viewing(status="cancelled")
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            confirm_viewing(
                mock_repo,
                viewing=viewing,
                confirmed_slot_ts=_future_jst_business_slot(),
                agent_user_id=99,
                org_id="org-001",
            )
        assert exc_info.value.status_code == 400


class TestCancelViewing:
    """Tests for cancel_viewing authorization and state machine."""

    def test_tenant_can_cancel_own_viewing(self) -> None:
        viewing = _make_viewing(status="requested", tenant_id=42, agent_id=99)
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = viewing

        cancel_viewing(mock_repo, viewing=viewing, actor_user_id=42, org_id="org-001")
        mock_repo.update_status.assert_called_once()
        assert mock_repo.update_status.call_args.kwargs["status"] == "cancelled"

    def test_agent_can_cancel_viewing(self) -> None:
        viewing = _make_viewing(status="confirmed", tenant_id=42, agent_id=99)
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = viewing

        cancel_viewing(mock_repo, viewing=viewing, actor_user_id=99, org_id="org-001")
        mock_repo.update_status.assert_called_once()

    def test_third_party_cannot_cancel(self) -> None:
        viewing = _make_viewing(status="requested", tenant_id=42, agent_id=99)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            cancel_viewing(mock_repo, viewing=viewing, actor_user_id=999, org_id="org-001")
        assert exc_info.value.status_code == 403

    def test_completed_viewing_cannot_be_cancelled(self) -> None:
        viewing = _make_viewing(status="completed", tenant_id=42, agent_id=99)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            cancel_viewing(mock_repo, viewing=viewing, actor_user_id=42, org_id="org-001")
        assert exc_info.value.status_code == 400

    def test_already_cancelled_cannot_cancel_again(self) -> None:
        viewing = _make_viewing(status="cancelled", tenant_id=42, agent_id=99)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            cancel_viewing(mock_repo, viewing=viewing, actor_user_id=42, org_id="org-001")
        assert exc_info.value.status_code == 400


class TestCompleteViewing:
    """Tests for complete_viewing — agent-only, confirmed → completed."""

    def test_agent_can_complete_confirmed_viewing(self) -> None:
        viewing = _make_viewing(status="confirmed", agent_id=99)
        mock_repo = MagicMock()
        mock_repo.update_status.return_value = viewing

        complete_viewing(mock_repo, viewing=viewing, agent_user_id=99)
        call_kwargs = mock_repo.update_status.call_args.kwargs
        assert call_kwargs["status"] == "completed"

    def test_non_agent_cannot_complete(self) -> None:
        viewing = _make_viewing(status="confirmed", agent_id=99)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            complete_viewing(mock_repo, viewing=viewing, agent_user_id=42)
        assert exc_info.value.status_code == 403

    def test_requested_viewing_cannot_be_completed(self) -> None:
        viewing = _make_viewing(status="requested", agent_id=99)
        mock_repo = MagicMock()

        with pytest.raises(HTTPException) as exc_info:
            complete_viewing(mock_repo, viewing=viewing, agent_user_id=99)
        assert exc_info.value.status_code == 400
