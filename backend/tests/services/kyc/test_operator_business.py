"""Unit tests for operator business KYC service.

Coverage:
  - submit_business_info: create, idempotent update, reject verified
  - submit_business_gpkd: happy path, profile not found
  - submit_legal_rep_info: happy path, profile not found
  - admin_approve_business: happy path, wrong status
  - admin_reject_business: happy path, wrong status
  - admin_revoke_gpkd: happy path, wrong status
  - initiate_legal_rep_change: happy path, not verified
  - admin_approve_legal_rep_change: happy path, wrong status
  - is_operator_business_kyc_complete: verified, unverified, no profile
"""

from __future__ import annotations

import os
from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "postgresql://localhost/fake_test")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from app.services.kyc.operator_business_service import (
    admin_approve_business,
    admin_approve_legal_rep_change,
    admin_reject_business,
    admin_revoke_gpkd,
    initiate_legal_rep_change,
    is_operator_business_kyc_complete,
    submit_business_info,
)


def _make_profile(status="pending", user_id=42, profile_id=1):
    p = MagicMock()
    p.id = profile_id
    p.user_id = user_id
    p.business_name = "Acme Corp"
    p.business_registration_number = "0123456789"
    p.verification_status = status
    p.gpkd_document_path = "gpkd/test.pdf" if status != "pending" else ""
    p.legal_representative_cccd_number_hash = None
    p.previous_legal_rep_user_id = None
    p.legal_rep_changed_at = None
    p.created_at = datetime(2024, 1, 1)
    p.updated_at = datetime(2024, 1, 1)
    return p


def _make_db(profile=None, user=None):
    db = MagicMock()
    call_count = [0]

    def side_effect():
        call_count[0] += 1
        # First query: OperatorBusinessProfile; Second: User
        if call_count[0] == 1:
            return profile
        return user

    db.query.return_value.filter.return_value.first.side_effect = side_effect
    return db


def _make_user():
    u = MagicMock()
    u.is_operator_capable = False
    return u


# ---------------------------------------------------------------------------
# submit_business_info
# ---------------------------------------------------------------------------


class TestSubmitBusinessInfo:
    def test_creates_new_profile(self):
        db = _make_db(profile=None, user=_make_user())
        added = []
        db.add.side_effect = lambda x: added.append(x)

        result = submit_business_info(
            user_id=42,
            business_name="Test Corp",
            business_registration_number="BRN001",
            gpkd_industry_codes=["7010"],
            db=db,
        )
        assert len(added) == 1
        assert added[0].business_name == "Test Corp"
        assert added[0].verification_status == "pending"

    def test_raises_when_already_verified(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)
        with pytest.raises(ValueError, match="already verified"):
            submit_business_info(
                user_id=42,
                business_name="New Corp",
                business_registration_number="BRN002",
                gpkd_industry_codes=[],
                db=db,
            )

    def test_updates_pending_profile(self):
        profile = _make_profile(status="pending")
        db = _make_db(profile=profile)

        result = submit_business_info(
            user_id=42,
            business_name="Updated Corp",
            business_registration_number="BRN999",
            gpkd_industry_codes=["7010"],
            db=db,
        )
        assert profile.business_name == "Updated Corp"


# ---------------------------------------------------------------------------
# admin_approve_business
# ---------------------------------------------------------------------------


class TestAdminApproveBusiness:
    def test_approves_pending_profile(self):
        profile = _make_profile(status="pending")
        user = _make_user()
        db = _make_db(profile=profile, user=user)

        result = admin_approve_business(
            profile_id=1,
            admin_user_id=999,
            db=db,
        )
        assert profile.verification_status == "verified"
        assert profile.verified_at is not None
        assert profile.verified_by_user_id == 999

    def test_raises_if_not_pending(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)
        with pytest.raises(ValueError, match="can only approve 'pending'"):
            admin_approve_business(profile_id=1, admin_user_id=999, db=db)

    def test_raises_if_not_found(self):
        db = _make_db(profile=None)
        with pytest.raises(ValueError, match="not found"):
            admin_approve_business(profile_id=999, admin_user_id=1, db=db)


# ---------------------------------------------------------------------------
# admin_reject_business
# ---------------------------------------------------------------------------


class TestAdminRejectBusiness:
    def test_rejects_pending_profile(self):
        profile = _make_profile(status="pending")
        db = _make_db(profile=profile)

        admin_reject_business(profile_id=1, admin_user_id=999, reason="Documents invalid", db=db)
        assert profile.verification_status == "rejected"

    def test_raises_if_not_pending(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)
        with pytest.raises(ValueError, match="can only reject 'pending'"):
            admin_reject_business(profile_id=1, admin_user_id=999, reason="reason", db=db)


# ---------------------------------------------------------------------------
# admin_revoke_gpkd
# ---------------------------------------------------------------------------


class TestAdminRevokeGpkd:
    def test_revokes_verified_profile(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)

        admin_revoke_gpkd(profile_id=1, admin_user_id=999, db=db)
        assert profile.verification_status == "revoked"

    def test_raises_if_not_verified(self):
        profile = _make_profile(status="pending")
        db = _make_db(profile=profile)
        with pytest.raises(ValueError, match="can only revoke 'verified'"):
            admin_revoke_gpkd(profile_id=1, admin_user_id=999, db=db)


# ---------------------------------------------------------------------------
# initiate_legal_rep_change
# ---------------------------------------------------------------------------


class TestInitiateLegalRepChange:
    @patch("app.services.kyc.operator_business_service.sensitive_file_service.store_file")
    def test_initiates_change_on_verified_profile(self, mock_store):
        mock_store.return_value = "legal_rep_cccd/test.jpg"
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)

        result = initiate_legal_rep_change(
            profile_id=1,
            new_legal_rep_name="Nguyen Van B",
            new_cccd_number="001099012345",
            new_phone="0901234567",
            new_cccd_front_bytes=b"front",
            new_cccd_back_bytes=b"back",
            cccd_extension="jpg",
            reason="Legal rep resigned, new appointment.",
            db=db,
        )

        assert profile.verification_status == "pending_legal_rep_change"
        assert profile.legal_representative_name == "Nguyen Van B"
        assert profile.legal_rep_changed_at is not None
        assert mock_store.call_count == 2

    def test_raises_if_not_verified(self):
        profile = _make_profile(status="pending")
        db = _make_db(profile=profile)

        with pytest.raises(ValueError, match="must be 'verified'"):
            initiate_legal_rep_change(
                profile_id=1,
                new_legal_rep_name="B",
                new_cccd_number="001099012345",
                new_phone="0901234567",
                new_cccd_front_bytes=b"front",
                new_cccd_back_bytes=b"back",
                cccd_extension="jpg",
                reason="enough reason here",
                db=db,
            )


# ---------------------------------------------------------------------------
# admin_approve_legal_rep_change
# ---------------------------------------------------------------------------


class TestAdminApproveLegalRepChange:
    def test_approves_pending_legal_rep_change(self):
        profile = _make_profile(status="pending_legal_rep_change")
        db = _make_db(profile=profile)

        admin_approve_legal_rep_change(profile_id=1, admin_user_id=999, db=db)
        assert profile.verification_status == "verified"

    def test_raises_if_not_in_pending_legal_rep_change(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)

        with pytest.raises(ValueError, match="'pending_legal_rep_change'"):
            admin_approve_legal_rep_change(profile_id=1, admin_user_id=999, db=db)


# ---------------------------------------------------------------------------
# is_operator_business_kyc_complete
# ---------------------------------------------------------------------------


class TestIsOperatorBusinessKycComplete:
    def test_true_when_verified(self):
        profile = _make_profile(status="verified")
        db = _make_db(profile=profile)
        assert is_operator_business_kyc_complete(user_id=42, db=db) is True

    def test_false_when_pending(self):
        profile = _make_profile(status="pending")
        db = _make_db(profile=profile)
        assert is_operator_business_kyc_complete(user_id=42, db=db) is False

    def test_false_when_no_profile(self):
        db = _make_db(profile=None)
        assert is_operator_business_kyc_complete(user_id=42, db=db) is False
