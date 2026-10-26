"""Unit tests for KB04WorkflowService (Phase 04).

Tests:
  - submit_fast_track(): operator_full auto-approve, non-operator_full pending
  - pre_file(): happy path, district flag=False rejects, district flag=NULL warns
  - verify_poa_format(): digital path (mock), notarized path
  - AC-55b: withdrawal flag on rejection (post-facto mock)
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Generator
from unittest.mock import MagicMock, patch

import pytest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session

from app.database import Base
import app.models  # noqa: F401
import app.domain  # noqa: F401
from app.domain.delegation import Delegation, DelegationApproval
from app.services.actor_context import ActorContext
from app.services.approval.kb04_workflow import (
    DistrictPreFileNotAccepted,
    KB04WorkflowService,
    POAVerificationFailed,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def engine():
    _engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=_engine)
    yield _engine
    _engine.dispose()


@pytest.fixture
def db(engine) -> Generator[Session, None, None]:
    connection = engine.connect()
    transaction = connection.begin()
    _Session = sessionmaker(bind=connection, autoflush=False, autocommit=False)
    session = _Session()
    yield session
    session.close()
    transaction.rollback()
    connection.close()


def _make_delegation(
    db: Session,
    owner_id: int = 1,
    operator_id: int = 2,
    role_preset: str = "operator_full",
    poa_format: str = "digital",
    poa_document_path: str | None = None,
) -> Delegation:
    d = Delegation(
        id=str(uuid.uuid4()),
        owner_id=owner_id,
        operator_id=operator_id,
        status="active",
        role_preset=role_preset,
        scope_type="all",
        commission_pct=Decimal("5.0"),
        threshold_monthly_rent_vnd=Decimal("5000000"),
        threshold_term_months=12,
        threshold_expense_vnd=Decimal("2000000"),
        threshold_rent_change_pct=Decimal("10.0"),
        threshold_refund_vnd=Decimal("1000000"),
        poa_format=poa_format,
        poa_document_path=poa_document_path,
        retention_tier="hot",
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(d)
    db.flush()
    return d


def _make_actor_ctx(user_id: int = 2, delegation_id: str | None = None) -> ActorContext:
    from app.services.permission_set import preset_to_permissions
    return ActorContext(
        actor_user_id=user_id,
        on_behalf_of_user_id=1,
        delegation_id=delegation_id,
        scope_type="all",
        scope_target_building_ids=None,
        permission_set=preset_to_permissions("operator_full"),
        actor_role="host",
        request_id=str(uuid.uuid4()),
    )


# ---------------------------------------------------------------------------
# submit_fast_track() tests
# ---------------------------------------------------------------------------


class TestKB04FastTrack:
    def test_operator_full_auto_approved(self, db: Session):
        """AC-55: operator_full → KB04 fast-track auto-approved at creation."""
        delegation = _make_delegation(db, role_preset="operator_full")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        approval = svc.submit_fast_track(
            actor_ctx=actor_ctx,
            delegation=delegation,
            khai_bao_id=42,
        )

        assert approval.status == "approved"
        assert approval.action_type == "kb04_fast_track"
        assert approval.sla_class == "kb04_fast_track_6h"

    def test_non_operator_full_stays_pending(self, db: Session):
        """Non-operator_full preset → KB04 fast-track stays pending (owner must approve)."""
        delegation = _make_delegation(db, role_preset="accountant")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        approval = svc.submit_fast_track(
            actor_ctx=actor_ctx,
            delegation=delegation,
            khai_bao_id=42,
        )

        assert approval.status == "pending"
        assert approval.sla_class == "kb04_fast_track_6h"

    def test_form_data_stored_in_payload(self, db: Session):
        """Form data is stored in action_payload_json."""
        delegation = _make_delegation(db, role_preset="accountant")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        form_data = {"tenant_name": "Nguyen Van A", "cccd": "012345678901"}
        approval = svc.submit_fast_track(
            actor_ctx=actor_ctx,
            delegation=delegation,
            khai_bao_id=55,
            form_data=form_data,
        )

        assert approval.action_payload_json is not None
        assert approval.action_payload_json["form_data"] == form_data
        assert approval.action_payload_json["khai_bao_id"] == 55

    def test_6h_sla_expiry(self, db: Session):
        """KB04 fast-track expires in 6h from created_at."""
        delegation = _make_delegation(db, role_preset="accountant")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        before = datetime.utcnow()
        approval = svc.submit_fast_track(
            actor_ctx=actor_ctx,
            delegation=delegation,
            khai_bao_id=100,
        )
        after = datetime.utcnow()

        expected_min = before + timedelta(hours=6)
        expected_max = after + timedelta(hours=6)
        assert expected_min <= approval.expires_at <= expected_max


# ---------------------------------------------------------------------------
# pre_file() tests (AC-55b, AC-55c)
# ---------------------------------------------------------------------------


class TestKB04PreFile:
    def _make_pre_file_request(self, contract_id: int = 1) -> dict:
        return {
            "tenant_full_name": "Nguyen Van A",
            "tenant_cccd": "012345678901",
            "expected_move_in_date": datetime.utcnow().isoformat(),
        }

    def test_pre_file_happy_path_district_accepted(self, db: Session):
        """AC-55b: pre-file when district_pre_file_accepted=True → creates pending approval."""
        delegation = _make_delegation(db, role_preset="operator_full")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        # Mock district flag check to return True (accepted)
        with patch.object(
            svc, "_check_district_flag_for_contract", return_value=(True, False)
        ):
            with patch.object(svc, "_update_contract_pre_file"):
                approval = svc.pre_file(
                    actor_ctx=actor_ctx,
                    delegation=delegation,
                    contract_id=1,
                    form_data=self._make_pre_file_request(),
                )

        # Even for operator_full, pre-file is always pending (AC-55b)
        assert approval.status == "pending"
        assert approval.action_type == "kb04_pre_file"
        assert approval.sla_class == "kb04_fast_track_6h"

    def test_pre_file_district_not_accepted_raises(self, db: Session):
        """AC-55c: district_pre_file_accepted=False → DistrictPreFileNotAccepted."""
        delegation = _make_delegation(db, role_preset="operator_full")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        with patch.object(
            svc, "_check_district_flag_for_contract", return_value=(False, False)
        ):
            with pytest.raises(DistrictPreFileNotAccepted):
                svc.pre_file(
                    actor_ctx=actor_ctx,
                    delegation=delegation,
                    contract_id=1,
                    form_data=self._make_pre_file_request(),
                )

    def test_pre_file_district_null_warning_allowed(self, db: Session):
        """AC-55c: district_pre_file_accepted=NULL → allowed with warning in payload."""
        delegation = _make_delegation(db, role_preset="accountant")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        with patch.object(
            svc, "_check_district_flag_for_contract", return_value=(None, True)
        ):
            with patch.object(svc, "_update_contract_pre_file"):
                approval = svc.pre_file(
                    actor_ctx=actor_ctx,
                    delegation=delegation,
                    contract_id=1,
                    form_data=self._make_pre_file_request(),
                )

        assert approval.status == "pending"
        # Warning should be in payload
        assert approval.action_payload_json.get("audit_warning") == "late_pre_file"

    def test_pre_file_operator_full_still_pending(self, db: Session):
        """AC-55b: pre-file always pending even for operator_full (AC-55b post-facto gate)."""
        delegation = _make_delegation(db, role_preset="operator_full")
        actor_ctx = _make_actor_ctx(user_id=2, delegation_id=delegation.id)
        svc = KB04WorkflowService(db)

        with patch.object(
            svc, "_check_district_flag_for_contract", return_value=(True, False)
        ):
            with patch.object(svc, "_update_contract_pre_file"):
                approval = svc.pre_file(
                    actor_ctx=actor_ctx,
                    delegation=delegation,
                    contract_id=1,
                    form_data=self._make_pre_file_request(),
                )

        # Pre-file never auto-approves (AC-55b: post-facto review)
        assert approval.status == "pending"


# ---------------------------------------------------------------------------
# verify_poa_format() tests (AC-55d)
# ---------------------------------------------------------------------------


class TestPOAFormat:
    def test_digital_poa_verified_via_mock(self, db: Session):
        """AC-55d: digital POA uses FastCA/VinaCA — mock returns True."""
        delegation = _make_delegation(db, poa_format="digital")
        approval = MagicMock()
        svc = KB04WorkflowService(db)

        # Mock digital_signature module to return a reference
        mock_client = MagicMock()
        mock_client.get_signature_reference.return_value = "fastca_ref_123"

        with patch("app.services.approval.kb04_workflow.get_signature_client", return_value=mock_client):
            result = svc.verify_poa_format(delegation, approval)

        assert result is True

    def test_digital_poa_vendor_returns_none_raises(self, db: Session):
        """AC-55d: digital POA but vendor returns None → POAVerificationFailed."""
        delegation = _make_delegation(db, poa_format="digital")
        approval = MagicMock()
        svc = KB04WorkflowService(db)

        mock_client = MagicMock()
        mock_client.get_signature_reference.return_value = None  # no signature registered

        with patch("app.services.approval.kb04_workflow.get_signature_client", return_value=mock_client):
            with pytest.raises(POAVerificationFailed):
                svc.verify_poa_format(delegation, approval)

    def test_notarized_poa_with_document_path(self, db: Session):
        """AC-55d: notarized POA with poa_document_path → verified."""
        delegation = _make_delegation(
            db, poa_format="notarized", poa_document_path="/uploads/poa_doc_123.pdf"
        )
        approval = MagicMock()
        svc = KB04WorkflowService(db)

        result = svc.verify_poa_format(delegation, approval)
        assert result is True

    def test_notarized_poa_without_document_path_raises(self, db: Session):
        """AC-55d: notarized POA with no document → POAVerificationFailed."""
        delegation = _make_delegation(
            db, poa_format="notarized", poa_document_path=None
        )
        approval = MagicMock()
        svc = KB04WorkflowService(db)

        with pytest.raises(POAVerificationFailed):
            svc.verify_poa_format(delegation, approval)

    def test_digital_vendor_not_configured_fallback_to_notarized(self, db: Session):
        """AC-55d: digital vendor not configured (AS-14 not signed) → fallback to notarized."""
        delegation = _make_delegation(
            db,
            poa_format="digital",
            poa_document_path="/uploads/poa_notarized.pdf",  # notarized doc also present
        )
        approval = MagicMock()
        svc = KB04WorkflowService(db)

        # Simulate VendorNotConfigured (AS-14 not signed)
        from app.integrations.digital_signature import VendorNotConfigured
        with patch(
            "app.services.approval.kb04_workflow.get_signature_client",
            side_effect=VendorNotConfigured("FASTCA_API_KEY not set"),
        ):
            # Should fallback to notarized check (poa_document_path is set → True)
            result = svc.verify_poa_format(delegation, approval)
            assert result is True
