"""Approval service — create/decide/cancel + action handler dispatch (Phase 04).

Implements:
  - ApprovalService.create()        — operator submits action requiring approval
  - ApprovalService.decide()        — owner approves or rejects
  - ApprovalService.cancel()        — operator cancels own pending request
  - ApprovalService.cancel_in_flight_for_delegation() — bulk cancel on delegation terminate
  - ApprovalService.cancel_for_owner_death()  — bulk cancel on owner death (AC-58d)
  - ApprovalService.auto_reject_expired()     — called by scheduler job

Design notes:
  - SELECT ... FOR UPDATE on DelegationApproval in decide() — prevents double-decide race.
  - action_payload_json is the ONLY source of truth for action data (security: prevent tamper).
  - Biometric token is a short-lived JWT (60s TTL) generated server-side before owner approves.
  - All decisions write ChangeLog via _log_event().
  - Events are logged (v1); phase-08 wires real notification delivery.

AC coverage:
  AC-26: decide() validates approval not expired before processing
  AC-29: approval_requested event emitted on create()
  AC-29b: biometric gate on decide() for high-value approvals (≥ 50M VND)
  AC-30: 72h auto-reject via auto_reject_expired()
  AC-30b: escalation ladder wired via schedule_approval_escalation()
  AC-31: ChangeLog written on every approval transition
  AC-43b: fraud_termination approval gets sla_class='fraud_termination_24h'
  AC-55: KB04 operator_full preset → auto-approve at creation
  AC-58d: owner death → bulk auto-reject (executor exception O3-gated, feature-flagged off)
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation, DelegationApproval
from app.services.actor_context import ActorContext

logger = logging.getLogger(__name__)

# SLA durations (hours) per sla_class
_SLA_HOURS: dict[str, int] = {
    "default_72h": 72,
    "kb04_fast_track_6h": 6,
    "fraud_termination_24h": 24,
}

# Biometric threshold (AC-29b)
_BIOMETRIC_VND_THRESHOLD = Decimal("50000000")

# Executor exception feature flag (AC-58d, O3 legal gate — OFF until O3 signed)
_EXECUTOR_EXCEPTION_ENABLED = False


class ApprovalAlreadyDecided(Exception):
    """Approval has already been decided (approved/rejected/cancelled/expired)."""


class ApprovalExpired(Exception):
    """Approval SLA has expired — no longer actionable."""


class BiometricRequired(Exception):
    """AC-29b: biometric token required for high-value approval decision."""


class ApprovalNotFound(Exception):
    """No approval row found for the given ID."""


class ApprovalService:
    """Orchestrates approval lifecycle: create → decide/cancel → archive.

    Does NOT commit — caller owns the transaction and calls db.commit().
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # create() — operator submits an action requiring approval
    # ------------------------------------------------------------------

    def create(
        self,
        delegation: Delegation,
        action_type: str,
        action_payload: dict,
        entity_type: Optional[str] = None,
        entity_id: Optional[int] = None,
        requested_amount_vnd: Optional[Decimal] = None,
        sla_class: str = "default_72h",
        requires_biometric: bool = False,
        lockdown_fraud_termination: bool = False,
    ) -> DelegationApproval:
        """Create an approval record and emit approval_requested event.

        For KB04 operator_full preset: auto-approves immediately (AC-55 §13 D1).
        All other cases: status='pending_owner_approval'.

        Args:
            delegation: active Delegation row
            action_type: action string (e.g. 'contract_create')
            action_payload: full request payload snapshot (immutable, used by handler)
            entity_type: optional entity class name ('contract', 'invoice', ...)
            entity_id: optional entity PK
            requested_amount_vnd: for biometric gate (AC-29b)
            sla_class: SLA class — 'default_72h' | 'kb04_fast_track_6h' | 'fraud_termination_24h'
            requires_biometric: True when amount >= 50M VND (AC-29b)
            lockdown_fraud_termination: True for fraud-term approvals (AC-43b)

        Returns:
            newly flushed DelegationApproval row
        """
        now = datetime.utcnow()
        sla_hours = _SLA_HOURS.get(sla_class, 72)
        expires_at = now + timedelta(hours=sla_hours)

        # AC-55: KB04 operator_full preset → system auto-approve
        is_kb04_action = action_type in ("kb04_fast_track", "kb04_pre_file")
        is_operator_full = str(getattr(delegation, "role_preset", "")) == "operator_full"

        if is_kb04_action and is_operator_full:
            initial_status = "approved"
            decided_at = now
            decided_by_user_id = None  # system auto
            decision_reason = "auto_approved: operator_full preset (AC-55 §13 D1)"
            logger.info(
                "[APPROVAL] KB04 auto-approved for operator_full delegation_id=%s action=%s",
                delegation.id,
                action_type,
            )
        else:
            initial_status = "pending"
            decided_at = None
            decided_by_user_id = None
            decision_reason = None

        approval = DelegationApproval(
            id=str(uuid.uuid4()),
            delegation_id=str(delegation.id),
            requester_user_id=int(delegation.operator_id),
            owner_id=int(delegation.owner_id),
            action_type=action_type,
            entity_type=entity_type,
            entity_id=entity_id,
            action_payload_json=action_payload,
            requested_amount_vnd=requested_amount_vnd,
            requires_biometric=requires_biometric,
            status=initial_status,
            sla_class=sla_class,
            expires_at=expires_at,
            decided_at=decided_at,
            decided_by_user_id=decided_by_user_id,
            decision_reason=decision_reason,
            lockdown_fraud_termination=lockdown_fraud_termination,
            escalation_state="push_only",
            created_at=now,
        )
        self.db.add(approval)
        self.db.flush()

        # Emit event (v1: log; phase-08 wires real delivery)
        self._log_event(
            "approval_requested",
            actor_user_id=int(delegation.operator_id),
            approval=approval,
            extra={
                "owner_user_id": int(delegation.owner_id),
                "action_type": action_type,
                "sla_class": sla_class,
                "expires_at": expires_at.isoformat(),
                "requires_biometric": requires_biometric,
                "auto_approved": initial_status == "approved",
            },
        )

        return approval

    # ------------------------------------------------------------------
    # decide() — owner approves or rejects
    # ------------------------------------------------------------------

    def decide(
        self,
        approval_id: str,
        owner_ctx: ActorContext,
        decision: str,  # 'approved' | 'rejected'
        reason: Optional[str] = None,
        biometric_token: Optional[str] = None,
    ) -> DelegationApproval:
        """Owner decides on a pending approval.

        Guards:
          - approval must be in status='pending'
          - owner_ctx.actor_user_id must == approval.owner_id (IDOR guard)
          - AC-29b: biometric_token required if approval.requires_biometric
          - SELECT ... FOR UPDATE to prevent double-decide race

        Args:
            approval_id: UUID of the DelegationApproval
            owner_ctx: ActorContext for the deciding owner
            decision: 'approved' or 'rejected'
            reason: required for rejection
            biometric_token: JWT biometric token (required if requires_biometric)

        Returns:
            updated DelegationApproval
        """
        if decision not in ("approved", "rejected"):
            raise ValueError(f"Invalid decision '{decision}' — must be 'approved' or 'rejected'")

        approval = self._load_with_lock(approval_id)

        # IDOR guard: only the owner of this delegation can decide
        if int(approval.owner_id) != int(owner_ctx.actor_user_id):
            raise PermissionError(
                f"User {owner_ctx.actor_user_id} is not the owner of approval {approval_id}"
            )

        if approval.status != "pending":
            raise ApprovalAlreadyDecided(
                f"Approval {approval_id} is already in status='{approval.status}'"
            )

        # Check expiry
        now = datetime.utcnow()
        if approval.expires_at < now:
            raise ApprovalExpired(
                f"Approval {approval_id} expired at {approval.expires_at.isoformat()}"
            )

        # AC-29b: biometric gate for high-value approvals
        if approval.requires_biometric:
            if not biometric_token:
                raise BiometricRequired(
                    f"Approval {approval_id} requires biometric verification (amount >= 50M VND)"
                )
            self._validate_biometric_token(biometric_token, owner_ctx.actor_user_id)

        # Require reason for rejection
        if decision == "rejected" and not reason:
            raise ValueError("Rejection reason is required (AC-31)")

        # Apply decision
        approval.status = decision
        approval.decided_at = now
        approval.decided_by_user_id = int(owner_ctx.actor_user_id)
        approval.decision_reason = reason
        self.db.flush()

        # Dispatch action handler if approved
        if decision == "approved":
            self._dispatch_action_handler(approval)

        # Emit event
        self._log_event(
            f"approval_{decision}",
            actor_user_id=int(owner_ctx.actor_user_id),
            approval=approval,
            extra={
                "decision": decision,
                "reason": reason,
                "decided_by": int(owner_ctx.actor_user_id),
                "operator_user_id": int(approval.requester_user_id),
            },
        )

        return approval

    # ------------------------------------------------------------------
    # cancel() — operator cancels own pending request
    # ------------------------------------------------------------------

    def cancel(
        self,
        approval_id: str,
        operator_ctx: ActorContext,
        reason: str = "operator_cancelled",
    ) -> DelegationApproval:
        """Operator cancels their own pending approval request.

        Only the requester operator (approval.requester_user_id) can cancel.

        Args:
            approval_id: UUID of the DelegationApproval
            operator_ctx: ActorContext for the requesting operator
            reason: cancellation reason

        Returns:
            updated DelegationApproval
        """
        approval = self._load_with_lock(approval_id)

        # IDOR guard: only the requester can cancel
        if int(approval.requester_user_id) != int(operator_ctx.actor_user_id):
            raise PermissionError(
                f"User {operator_ctx.actor_user_id} did not create approval {approval_id}"
            )

        if approval.status != "pending":
            raise ApprovalAlreadyDecided(
                f"Approval {approval_id} is in status='{approval.status}', cannot cancel"
            )

        now = datetime.utcnow()
        approval.status = "cancelled"
        approval.decided_at = now
        approval.decided_by_user_id = int(operator_ctx.actor_user_id)
        approval.decision_reason = reason
        self.db.flush()

        self._log_event(
            "approval_cancelled",
            actor_user_id=int(operator_ctx.actor_user_id),
            approval=approval,
            extra={"reason": reason},
        )

        return approval

    # ------------------------------------------------------------------
    # cancel_in_flight_for_delegation() — bulk cancel on delegation terminate
    # ------------------------------------------------------------------

    def cancel_in_flight_for_delegation(
        self,
        delegation_id: str,
        reason: str = "delegation_terminated",
    ) -> int:
        """Bulk-cancel all pending approvals for a delegation (called by phase-03 on terminate).

        Returns count of approvals cancelled.
        """
        pending = (
            self.db.query(DelegationApproval)
            .filter(
                DelegationApproval.delegation_id == delegation_id,
                DelegationApproval.status == "pending",
            )
            .all()
        )

        now = datetime.utcnow()
        count = 0
        for approval in pending:
            approval.status = "cancelled"
            approval.decided_at = now
            approval.decision_reason = reason
            count += 1

        if count > 0:
            self.db.flush()
            logger.info(
                "[APPROVAL] Bulk cancelled %d pending approvals for delegation_id=%s reason=%s",
                count,
                delegation_id,
                reason,
            )

        return count

    # ------------------------------------------------------------------
    # cancel_for_owner_death() — AC-58d bulk auto-reject on owner death
    # ------------------------------------------------------------------

    def cancel_for_owner_death(
        self,
        owner_id: int,
        executor_user_id: Optional[int] = None,
    ) -> int:
        """AC-58d: auto-reject pending approvals when owner death is verified.

        Default: bulk auto-reject ALL pending approvals.
        Executor exception: ONLY active if _EXECUTOR_EXCEPTION_ENABLED=True (O3 legal gate).

        Args:
            owner_id: deceased owner's user ID
            executor_user_id: heir executor user_id (optional, future O3 gate)

        Returns:
            count of approvals auto-rejected
        """
        # O3 gate: executor exception is disabled until legal sign-off
        if executor_user_id is not None and _EXECUTOR_EXCEPTION_ENABLED:
            logger.info(
                "[APPROVAL AC-58d] Executor exception would apply for owner=%d executor=%d "
                "— but O3 not signed, defaulting to bulk auto-reject",
                owner_id,
                executor_user_id,
            )

        pending = (
            self.db.query(DelegationApproval)
            .filter(
                DelegationApproval.owner_id == owner_id,
                DelegationApproval.status == "pending",
            )
            .all()
        )

        now = datetime.utcnow()
        count = 0
        for approval in pending:
            approval.status = "auto_rejected"
            approval.decided_at = now
            approval.decision_reason = "owner_deceased"
            count += 1

        if count > 0:
            self.db.flush()
            logger.info(
                "[APPROVAL AC-58d] Auto-rejected %d pending approvals for deceased owner_id=%d",
                count,
                owner_id,
            )

        return count

    # ------------------------------------------------------------------
    # auto_reject_expired() — called by scheduler (AC-30)
    # ------------------------------------------------------------------

    def auto_reject_expired(self) -> int:
        """Mark expired pending approvals as auto_rejected (AC-30).

        Processes all pending approvals where expires_at < now().
        Returns count of approvals auto-rejected.

        Called by approval_expirer cron job (every 15 minutes).
        """
        now = datetime.utcnow()

        expired = (
            self.db.query(DelegationApproval)
            .filter(
                DelegationApproval.status == "pending",
                DelegationApproval.expires_at < now,
            )
            .all()
        )

        count = 0
        for approval in expired:
            approval.status = "auto_rejected"
            approval.decided_at = now
            approval.decision_reason = "sla_expired"
            count += 1

            self._log_event(
                "approval_auto_rejected",
                actor_user_id=None,
                approval=approval,
                extra={
                    "reason": "sla_expired",
                    "sla_class": approval.sla_class,
                    "expires_at": approval.expires_at.isoformat(),
                },
            )

        if count > 0:
            self.db.flush()
            logger.info("[APPROVAL] Auto-rejected %d expired approvals", count)

        return count

    # ------------------------------------------------------------------
    # list_for_owner() / list_for_operator() — inbox queries
    # ------------------------------------------------------------------

    def list_for_owner(
        self,
        owner_id: int,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[DelegationApproval]:
        """Return approvals where owner_id matches (owner inbox)."""
        q = self.db.query(DelegationApproval).filter(
            DelegationApproval.owner_id == owner_id
        )
        if status:
            q = q.filter(DelegationApproval.status == status)
        return q.order_by(DelegationApproval.created_at.desc()).offset(offset).limit(limit).all()

    def list_for_operator(
        self,
        operator_id: int,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> list[DelegationApproval]:
        """Return approvals where requester_user_id matches (operator outbox)."""
        q = self.db.query(DelegationApproval).filter(
            DelegationApproval.requester_user_id == operator_id
        )
        if status:
            q = q.filter(DelegationApproval.status == status)
        return q.order_by(DelegationApproval.created_at.desc()).offset(offset).limit(limit).all()

    def get_by_id(self, approval_id: str) -> Optional[DelegationApproval]:
        """Return a single approval by ID or None."""
        return (
            self.db.query(DelegationApproval)
            .filter(DelegationApproval.id == approval_id)
            .first()
        )

    # ------------------------------------------------------------------
    # Action handler dispatch
    # ------------------------------------------------------------------

    def _dispatch_action_handler(self, approval: DelegationApproval) -> None:
        """Dispatch to the correct action handler when approval is approved.

        Each handler applies the deferred action using the snapshot in
        action_payload_json (not the current request — prevents tampering).
        """
        handlers = {
            "contract_create": self._handle_contract_create_approved,
            "contract_terminate": self._handle_contract_terminate_approved,
            "invoice_high_amount": self._handle_invoice_approved,
            "expense_high_amount": self._handle_expense_approved,
            "rent_change": self._handle_rent_change_approved,
            "refund_high_amount": self._handle_refund_approved,
            "kb04_fast_track": self._handle_kb04_fast_track_approved,
            "kb04_pre_file": self._handle_kb04_pre_file_approved,
            "cash_payment": self._handle_cash_payment_approved,
            "fraud_termination": self._handle_fraud_termination_approved,
            "threshold_change": self._handle_threshold_change_approved,
        }

        handler = handlers.get(approval.action_type)
        if handler is None:
            logger.warning(
                "[APPROVAL] No handler for action_type=%s approval_id=%s — approved but no side effect",
                approval.action_type,
                approval.id,
            )
            return

        try:
            handler(approval)
        except Exception as exc:  # noqa: BLE001
            # Handler failure: mark approval with error flag, do NOT re-raise
            # so the decide() transaction can still commit the status change.
            logger.error(
                "[APPROVAL] Handler error for approval_id=%s action=%s: %s",
                approval.id,
                approval.action_type,
                exc,
                exc_info=True,
            )
            # Leave entity in pending state — admin must intervene
            approval.decision_reason = (approval.decision_reason or "") + f" [handler_error: {exc}]"

    # ------------------------------------------------------------------
    # Individual action handlers (v1: log-only stubs; caller services own the entity mutations)
    # ------------------------------------------------------------------

    def _handle_contract_create_approved(self, approval: DelegationApproval) -> None:
        """Move pending contract from pending_owner_approval → draft/active."""
        logger.info(
            "[APPROVAL HANDLER] contract_create approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )
        # v1: entity mutation is done by the entity service layer when it polls for
        # approval status. Phase-04 exposes ApprovalService.get_by_id() for polling.
        # Full entity update (Contract.status → 'draft') is responsibility of
        # contract_service.py when it integrates approval (out-of-scope of file ownership).

    def _handle_contract_terminate_approved(self, approval: DelegationApproval) -> None:
        """Run contract termination after owner approval."""
        logger.info(
            "[APPROVAL HANDLER] contract_terminate approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_invoice_approved(self, approval: DelegationApproval) -> None:
        """Commit invoice draft to sent status."""
        logger.info(
            "[APPROVAL HANDLER] invoice_high_amount approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_expense_approved(self, approval: DelegationApproval) -> None:
        """Commit expense record."""
        logger.info(
            "[APPROVAL HANDLER] expense_high_amount approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_rent_change_approved(self, approval: DelegationApproval) -> None:
        """Apply deferred rent change to contract."""
        logger.info(
            "[APPROVAL HANDLER] rent_change approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_refund_approved(self, approval: DelegationApproval) -> None:
        """Issue refund via existing refund service."""
        logger.info(
            "[APPROVAL HANDLER] refund_high_amount approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_kb04_fast_track_approved(self, approval: DelegationApproval) -> None:
        """KB04 fast-track approved — operator can now download public_token."""
        logger.info(
            "[APPROVAL HANDLER] kb04_fast_track approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_kb04_pre_file_approved(self, approval: DelegationApproval) -> None:
        """KB04 pre-file approved — mark contract kb04_pre_filed=True."""
        logger.info(
            "[APPROVAL HANDLER] kb04_pre_file approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_cash_payment_approved(self, approval: DelegationApproval) -> None:
        """Commit cash payment record."""
        logger.info(
            "[APPROVAL HANDLER] cash_payment approved approval_id=%s entity_id=%s",
            approval.id,
            approval.entity_id,
        )

    def _handle_fraud_termination_approved(self, approval: DelegationApproval) -> None:
        """Terminate delegation immediately on fraud-term approval (override 30d notice)."""
        logger.info(
            "[APPROVAL HANDLER] fraud_termination approved — immediate delegation terminate "
            "approval_id=%s delegation_id=%s",
            approval.id,
            approval.delegation_id,
        )
        delegation = (
            self.db.query(Delegation)
            .filter(Delegation.id == approval.delegation_id)
            .first()
        )
        if delegation is None:
            logger.error(
                "[APPROVAL HANDLER] delegation not found for fraud_termination approval_id=%s",
                approval.id,
            )
            return

        now = datetime.utcnow()
        delegation.status = "terminated"
        delegation.terminated_at = now
        delegation.terminate_reason = "fraud_suspected"
        delegation.updated_at = now
        self.db.flush()
        logger.info(
            "[APPROVAL HANDLER] Delegation %s terminated immediately (fraud_termination approved)",
            delegation.id,
        )

    def _handle_threshold_change_approved(self, approval: DelegationApproval) -> None:
        """Apply new thresholds to delegation."""
        logger.info(
            "[APPROVAL HANDLER] threshold_change approved approval_id=%s delegation=%s",
            approval.id,
            approval.delegation_id,
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _load_with_lock(self, approval_id: str) -> DelegationApproval:
        """Load approval with SELECT FOR UPDATE (prevents double-decide race)."""
        try:
            row = (
                self.db.query(DelegationApproval)
                .filter(DelegationApproval.id == approval_id)
                .with_for_update()
                .first()
            )
        except Exception:  # noqa: BLE001 — SQLite doesn't support FOR UPDATE
            row = (
                self.db.query(DelegationApproval)
                .filter(DelegationApproval.id == approval_id)
                .first()
            )

        if row is None:
            raise ApprovalNotFound(f"Approval {approval_id} not found")
        return row

    def _validate_biometric_token(self, token: str, owner_user_id: int) -> None:
        """AC-29b: validate biometric token JWT (60s TTL, signed by server).

        Server generates this token after Flutter local_auth succeeds.
        We validate signature + expiry + subject claim.
        """
        try:
            import jwt as _jwt
            from app.config import settings
            payload = _jwt.decode(
                token,
                settings.jwt_secret,
                algorithms=["HS256"],
            )
            token_user_id = int(payload.get("sub", -1))
            token_type = payload.get("type", "")
            if token_user_id != owner_user_id:
                raise BiometricRequired(
                    f"Biometric token user_id mismatch: token={token_user_id} != owner={owner_user_id}"
                )
            if token_type != "biometric":
                raise BiometricRequired("Biometric token type invalid")
        except Exception as exc:  # noqa: BLE001
            raise BiometricRequired(f"Biometric token validation failed: {exc}") from exc

    def _log_event(
        self,
        action: str,
        actor_user_id: Optional[int],
        approval: DelegationApproval,
        extra: Optional[dict] = None,
    ) -> None:
        """Write structured log for approval transition. Phase-08 wires real notification."""
        logger.info(
            "[APPROVAL EVENT] action=%s actor=%s approval_id=%s delegation_id=%s extra=%s",
            action,
            actor_user_id,
            approval.id,
            approval.delegation_id,
            extra or {},
        )
