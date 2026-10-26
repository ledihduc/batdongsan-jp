"""KB04 workflow service — fast-track + pre-file + POA format handling (Phase 04).

Implements:
  - KB04WorkflowService.submit_fast_track()  — operator-initiated KB04 (AC-55)
  - KB04WorkflowService.pre_file()           — pre-move-in CT01 filing (AC-55b)
  - KB04WorkflowService.check_district_flag() — district pre-file acceptance (AC-55c)
  - KB04WorkflowService.verify_poa_format()   — POA format gate at approval time (AC-55d)

AC coverage:
  AC-55: KB04 always requires approval; operator_full = system auto-approve at creation
  AC-55b: pre-file workflow — gate='pending_pre_file_review'; owner approval post-facto (6h)
  AC-55c: district_pre_file_accepted flag check; NULL = warn; False = reject with fallback hint
  AC-55d: POA format honored: digital → FastCA/VinaCA; notarized → check poa_document_path
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation, DelegationApproval
from app.services.actor_context import ActorContext
from app.services.approval.approval_service import ApprovalService

try:
    from app.integrations.digital_signature import get_signature_client
except ImportError:  # pragma: no cover — integration module optional
    get_signature_client = None  # type: ignore[assignment]

logger = logging.getLogger(__name__)


class DistrictPreFileNotAccepted(Exception):
    """AC-55c: district does not accept pre-file CT01 submissions."""


class POAVerificationFailed(Exception):
    """AC-55d: POA verification failed — approval stays pending, admin alerted."""


class KB04WorkflowService:
    """Orchestrates KB04 tenant registration approvals (fast-track + pre-file).

    Delegates approval creation to ApprovalService.
    Does NOT commit — caller owns the transaction.
    """

    def __init__(self, db: Session) -> None:
        self.db = db
        self.approval_svc = ApprovalService(db)

    # ------------------------------------------------------------------
    # submit_fast_track() — AC-55
    # ------------------------------------------------------------------

    def submit_fast_track(
        self,
        actor_ctx: ActorContext,
        delegation: Delegation,
        khai_bao_id: int,
        form_data: Optional[dict] = None,
    ) -> DelegationApproval:
        """Operator submits KB04 tenant registration for owner approval.

        For operator_full preset: auto-approved immediately.
        For other presets: full 6h approval flow.

        Args:
            actor_ctx: operator's ActorContext
            delegation: active Delegation row
            khai_bao_id: ID of the KhaiBaoTamTru record
            form_data: optional KB04 CT01 form data snapshot

        Returns:
            DelegationApproval (auto-approved if operator_full, else pending)
        """
        payload = {
            "khai_bao_id": khai_bao_id,
            "form_data": form_data or {},
            "submitted_by": actor_ctx.actor_user_id,
            "submitted_at": datetime.utcnow().isoformat(),
        }

        approval = self.approval_svc.create(
            delegation=delegation,
            action_type="kb04_fast_track",
            action_payload=payload,
            entity_type="khai_bao_tam_tru",
            entity_id=khai_bao_id,
            sla_class="kb04_fast_track_6h",
        )

        logger.info(
            "[KB04] Fast-track approval created approval_id=%s khai_bao_id=%d status=%s",
            approval.id,
            khai_bao_id,
            approval.status,
        )

        return approval

    # ------------------------------------------------------------------
    # pre_file() — AC-55b
    # ------------------------------------------------------------------

    def pre_file(
        self,
        actor_ctx: ActorContext,
        delegation: Delegation,
        contract_id: int,
        form_data: dict,
    ) -> DelegationApproval:
        """Operator submits CT01 form BEFORE tenant move-in (pre-file).

        Checks:
          - AC-55c: district must accept pre-file (district_pre_file_accepted)
          - Creates KB04 approval with action_type='kb04_pre_file'
          - Sets gate='pending_pre_file_review' (post-facto owner approval within 6h)

        Args:
            actor_ctx: operator's ActorContext
            delegation: active Delegation row
            contract_id: contract being pre-filed for
            form_data: CT01 form data dict (stored in contracts.kb04_form_data_json)

        Returns:
            DelegationApproval (always pending — even for operator_full, pre-file needs owner)
        Raises:
            DistrictPreFileNotAccepted: if district flag is False (AC-55c)
        """
        # AC-55c: check district pre-file flag on the building linked to contract
        district_ok, district_warning = self._check_district_flag_for_contract(contract_id)
        if district_ok is False:
            raise DistrictPreFileNotAccepted(
                "This district does not accept CT01 pre-file submissions. "
                "Use the approve-then-file workflow instead (district_pre_file_accepted=False)."
            )
        if district_warning:
            logger.warning(
                "[KB04 AC-55c] district_pre_file_accepted is NULL for contract_id=%d — "
                "allowing pre-file but flagging audit.warning='late_pre_file'",
                contract_id,
            )

        now = datetime.utcnow()
        payload = {
            "contract_id": contract_id,
            "form_data": form_data,
            "submitted_by": actor_ctx.actor_user_id,
            "submitted_at": now.isoformat(),
            "gate": "pending_pre_file_review",
            "audit_warning": "late_pre_file" if district_warning else None,
        }

        # Pre-file: operator_full does NOT auto-approve — owner always reviews (AC-55b)
        # We temporarily override by creating approval directly to force pending status.
        approval = self._create_pre_file_approval(delegation, payload, contract_id)

        # Mark contract with kb04_pre_filed flag + form data snapshot
        self._update_contract_pre_file(contract_id, form_data, approval.id)

        logger.info(
            "[KB04 pre-file] Approval created approval_id=%s contract_id=%d status=%s",
            approval.id,
            contract_id,
            approval.status,
        )

        return approval

    # ------------------------------------------------------------------
    # verify_poa_format() — AC-55d
    # ------------------------------------------------------------------

    def verify_poa_format(self, delegation: Delegation, approval: DelegationApproval) -> bool:
        """AC-55d: verify POA format is satisfied before dispatching kb04_* action.

        Called from action handler when KB04 approval is approved.
        - digital: calls FastCA/VinaCA thin client
        - notarized: checks poa_document_path is not NULL

        Returns True if POA format verified, raises POAVerificationFailed otherwise.
        """
        poa_format = str(getattr(delegation, "poa_format", "notarized"))

        if poa_format == "digital":
            return self._verify_digital_poa(delegation, approval)
        else:
            return self._verify_notarized_poa(delegation, approval)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _check_district_flag_for_contract(
        self, contract_id: int
    ) -> tuple[Optional[bool], bool]:
        """Check buildings.district_pre_file_accepted for the contract's building.

        Returns:
            (flag_value, has_warning)
            flag_value: True = accepted, False = rejected, None = unknown
            has_warning: True when flag is NULL (unknown — log warning)
        """
        try:
            from sqlalchemy import text
            row = self.db.execute(
                text(
                    "SELECT b.district_pre_file_accepted "
                    "FROM contracts c "
                    "JOIN rooms r ON r.id = c.room_id "
                    "JOIN buildings b ON b.id = r.building_id "
                    "WHERE c.id = :contract_id LIMIT 1"
                ),
                {"contract_id": contract_id},
            ).fetchone()

            if row is None:
                # Contract or building not found — allow with warning
                return None, True

            flag = row[0]
            if flag is None:
                return None, True  # Unknown — allow with warning
            return bool(flag), False

        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[KB04 AC-55c] Could not check district_pre_file_accepted for contract_id=%d: %s",
                contract_id,
                exc,
            )
            return None, True  # Fail open with warning

    def _create_pre_file_approval(
        self,
        delegation: Delegation,
        payload: dict,
        contract_id: int,
    ) -> DelegationApproval:
        """Create pre-file approval — always pending (even for operator_full).

        We cannot use ApprovalService.create() directly because it auto-approves
        for operator_full on KB04 actions. Pre-file always needs owner review (AC-55b).
        """
        import uuid as _uuid
        from datetime import timedelta
        from app.domain.delegation import DelegationApproval as _DA

        now = datetime.utcnow()
        expires_at = now + timedelta(hours=6)  # kb04_fast_track_6h SLA

        approval = _DA(
            id=str(_uuid.uuid4()),
            delegation_id=str(delegation.id),
            requester_user_id=int(delegation.operator_id),
            owner_id=int(delegation.owner_id),
            action_type="kb04_pre_file",
            entity_type="contract",
            entity_id=contract_id,
            action_payload_json=payload,
            requested_amount_vnd=None,
            requires_biometric=False,
            status="pending",  # always pending — pre-file gate (AC-55b)
            sla_class="kb04_fast_track_6h",
            expires_at=expires_at,
            lockdown_fraud_termination=False,
            escalation_state="push_only",
            created_at=now,
        )
        self.db.add(approval)
        self.db.flush()
        return approval

    def _update_contract_pre_file(
        self, contract_id: int, form_data: dict, approval_id: str
    ) -> None:
        """Set contracts.kb04_pre_filed=True and store form snapshot (AC-55c).

        Graceful: if columns don't exist (migration not yet applied), logs and continues.
        """
        try:
            from sqlalchemy import text
            self.db.execute(
                text(
                    "UPDATE contracts SET "
                    "kb04_pre_filed = TRUE, "
                    "kb04_form_data = :form_data "
                    "WHERE id = :contract_id"
                ),
                {
                    "form_data": str(form_data),  # JSON string for SQLite compat
                    "contract_id": contract_id,
                },
            )
            self.db.flush()
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[KB04 pre-file] Could not update contract kb04_pre_filed for contract_id=%d: %s "
                "— continuing (migration may not yet be applied)",
                contract_id,
                exc,
            )

    def _verify_digital_poa(
        self, delegation: Delegation, approval: DelegationApproval
    ) -> bool:
        """AC-55d: verify digital POA via FastCA/VinaCA thin client.

        If vendor unavailable (AS-14 contract not signed): fallback to notarized check.
        """
        try:
            if get_signature_client is None:
                raise ImportError("digital_signature integration not loaded")
            client = get_signature_client()
            ref = client.get_signature_reference(str(delegation.id))
            if ref:
                logger.info(
                    "[KB04 POA] Digital signature verified delegation_id=%s ref=%s",
                    delegation.id,
                    ref,
                )
                return True
            raise POAVerificationFailed(
                f"FastCA/VinaCA returned no signature reference for delegation {delegation.id}"
            )
        except ImportError:
            # Integration module not available — fallback to notarized
            logger.warning(
                "[KB04 POA AC-55d] digital_signature integration not available — "
                "falling back to notarized_poa check for delegation_id=%s",
                delegation.id,
            )
            return self._verify_notarized_poa(delegation, approval)
        except POAVerificationFailed:
            raise
        except Exception as exc:  # noqa: BLE001
            # Vendor circuit failure — fallback to notarized
            logger.error(
                "[KB04 POA AC-55d] Vendor error: %s — falling back to notarized for delegation_id=%s",
                exc,
                delegation.id,
            )
            return self._verify_notarized_poa(delegation, approval)

    def _verify_notarized_poa(
        self, delegation: Delegation, approval: DelegationApproval
    ) -> bool:
        """AC-55d: verify notarized POA by checking poa_document_path is non-NULL."""
        doc_path = getattr(delegation, "poa_document_path", None)
        if doc_path:
            logger.info(
                "[KB04 POA] Notarized POA document present delegation_id=%s path=%s",
                delegation.id,
                doc_path,
            )
            return True
        raise POAVerificationFailed(
            f"No notarized POA document uploaded for delegation {delegation.id}. "
            "Upload POA before approving KB04."
        )
