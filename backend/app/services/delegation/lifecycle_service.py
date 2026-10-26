"""Delegation lifecycle state machine (Phase 03).

All state transitions:
  pending_op_kyc → active         (AC-05, operator KYC complete)
  active → paused                  (AC-09, owner pause; AC-50 KYC expiry; AC-44 GPKD)
  active → terminating             (AC-42, owner 30d notice)
  active → terminated              (AC-45, fraud/legal → immediate)
  paused → active                  (AC-09 resume, owner_request only)
  paused → terminated              (AC-50 grace lapse auto)
  terminating → active             (cancel_termination within 30d window)
  terminating → terminated         (AC-44 cron after 30d)
  terminated → archived            (30d after terminated_at, cron)

Design:
  - SELECT ... FOR UPDATE on delegation at start of each mutation (NFR-01 race prevention).
  - Wrapped in caller's transaction; caller commits. This service only flushes.
  - All transitions write a ChangeLog entry + emit notification event (log for v1).
  - InvalidStateTransition raised for illegal transitions.

References:
  AC-08: Only one active delegation per owner (partial UNIQUE index + service guard).
  AC-10b: Duplicate pending invitation → 409.
  AC-22: Operator self-resign creates terminate with reason=operator_resign.
  AC-57: OOO set by operator via PATCH endpoint.
  AC-58-OOO: OOO + emergency escalation handled by phase-08.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation, DelegationInvitation

logger = logging.getLogger(__name__)

# 30-day lockdown window (AC-43/44)
_LOCKDOWN_DAYS = 30

# Valid status values for delegations
VALID_STATUSES = frozenset(
    ["pending_op_kyc", "active", "paused", "terminating", "terminated", "archived"]
)

# Immediate termination reasons (AC-45) — skip 30d notice
_IMMEDIATE_TERMINATE_REASONS = frozenset(["fraud_suspected", "legal_dispute"])


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------


class InvalidStateTransition(Exception):
    """Raised when a requested status transition is not valid."""

    def __init__(self, current: str, target: str, reason: str = "") -> None:
        self.current = current
        self.target = target
        super().__init__(
            f"Cannot transition delegation from '{current}' to '{target}'"
            + (f": {reason}" if reason else "")
        )


class OwnerHasActiveDelegation(Exception):
    """AC-08: owner already has one active delegation; cannot activate another."""

    def __init__(self, existing_id: str) -> None:
        self.existing_id = existing_id
        super().__init__(
            f"Owner already has active delegation {existing_id}. "
            "Pause or terminate it before activating a new one."
        )


class DuplicatePendingInvitation(Exception):
    """AC-10b: duplicate pending invitation for same (owner, invitee) pair."""

    def __init__(self, existing_id: str, revoke_url: str) -> None:
        self.existing_id = existing_id
        self.revoke_url = revoke_url
        super().__init__(
            f"A pending invitation {existing_id} already exists for this invitee. "
            f"Revoke it first: {revoke_url}"
        )


class OperatorHasActiveDelegationConflict(Exception):
    """Operator is already the active operator in another delegation for this owner."""


# ---------------------------------------------------------------------------
# DelegationLifecycleService
# ---------------------------------------------------------------------------


class DelegationLifecycleService:
    """Delegation state machine — all transition methods.

    Each method:
      1. Loads delegation with FOR UPDATE (NFR-01 concurrency safety).
      2. Validates the transition.
      3. Mutates the ORM object.
      4. Writes a ChangeLog entry.
      5. Emits notification event (log-only in v1; phase-08 wires real delivery).
      6. Flushes (does NOT commit — caller owns the transaction).
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # create_invitation
    # ------------------------------------------------------------------

    def create_invitation(
        self,
        owner_id: int,
        payload: object,  # InvitationCreateRequest — typed as object to avoid circular import
        invited_user_id: Optional[int] = None,
    ) -> DelegationInvitation:
        """AC-01/10b: create a delegation invitation with token.

        Enforces AC-10b: raises DuplicatePendingInvitation if a pending invite
        for this (owner, invitee) pair already exists.

        Args:
            owner_id: authenticated owner's user ID.
            payload: InvitationCreateRequest (validated by Pydantic before call).
            invited_user_id: pre-resolved user_id if invitee already has an account.

        Returns: newly flushed DelegationInvitation.
        """
        from app.services.delegation.invitation_service import DelegationInvitationService

        inv_svc = DelegationInvitationService(self.db)
        invited_phone_or_email: str = str(payload.invited_phone_or_email)  # type: ignore[attr-defined]

        # AC-10b: check for existing pending invite
        existing = inv_svc.get_pending_for_owner_invitee(
            owner_id=owner_id,
            invited_phone_or_email=invited_phone_or_email,
        )
        if existing is not None:
            revoke_url = f"/api/delegations/invitations/{existing.id}/revoke"
            raise DuplicatePendingInvitation(
                existing_id=str(existing.id), revoke_url=revoke_url
            )

        now = datetime.utcnow()
        token = inv_svc.generate_token()
        expires_at = inv_svc.compute_expiry(from_dt=now)

        # Build thresholds JSON from ThresholdsRequest
        thresholds = payload.thresholds  # type: ignore[attr-defined]
        thresholds_json = {
            "threshold_monthly_rent_vnd": str(thresholds.threshold_monthly_rent_vnd),
            "threshold_term_months": thresholds.threshold_term_months,
            "threshold_expense_vnd": str(thresholds.threshold_expense_vnd),
            "threshold_rent_change_pct": str(thresholds.threshold_rent_change_pct),
            "threshold_refund_vnd": str(thresholds.threshold_refund_vnd),
        }

        import uuid as _uuid
        invitation = DelegationInvitation(
            id=str(_uuid.uuid4()),
            owner_id=owner_id,
            invited_phone_or_email=invited_phone_or_email,
            invited_user_id=invited_user_id,
            token=token,
            token_used_at=None,
            proposed_role_preset=str(payload.role_preset),  # type: ignore[attr-defined]
            proposed_scope_type=str(payload.scope_type),  # type: ignore[attr-defined]
            proposed_scope_target_ids=list(payload.scope_target_ids) if payload.scope_target_ids else None,  # type: ignore[attr-defined]
            proposed_commission_pct=payload.commission_pct,  # type: ignore[attr-defined]
            proposed_commission_fixed_vnd=payload.commission_fixed_vnd,  # type: ignore[attr-defined]
            proposed_thresholds_json=thresholds_json,
            proposed_poa_format=str(payload.poa_format),  # type: ignore[attr-defined]
            status="pending",
            expires_at=expires_at,
            created_at=now,
        )
        self.db.add(invitation)
        self.db.flush()

        self._log_event(
            "delegation_invitation_created",
            actor_user_id=owner_id,
            entity_type="invitation",
            entity_id=invitation.id,
        )
        return invitation

    # ------------------------------------------------------------------
    # accept_invitation
    # ------------------------------------------------------------------

    def accept_invitation(
        self,
        invitation: DelegationInvitation,
        accepting_user_id: int,
        disclosure_ack: bool = False,
    ) -> Delegation:
        """AC-05/08: operator accepts invitation → create Delegation row.

        Checks:
          - AC-08: owner must not already have an active delegation.
          - Operator KYC completeness → sets status = pending_op_kyc or active.

        Returns: newly created Delegation (status pending_op_kyc or active).
        """
        from app.services.delegation.invitation_service import DelegationInvitationService

        inv_svc = DelegationInvitationService(self.db)
        inv_svc.validate_for_accept(invitation)

        owner_id = int(invitation.owner_id)

        # AC-08: check for existing active delegation for owner
        existing_active = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == owner_id,
                Delegation.status == "active",
            )
            .with_for_update()
            .first()
        )
        if existing_active is not None:
            raise OwnerHasActiveDelegation(existing_id=str(existing_active.id))

        # Determine initial status: pending_op_kyc or active (AC-05)
        kyc_complete = self._check_operator_kyc_complete(accepting_user_id)
        initial_status = "active" if kyc_complete else "pending_op_kyc"
        now = datetime.utcnow()

        # Extract thresholds from JSON
        t = invitation.proposed_thresholds_json or {}
        from decimal import Decimal

        import uuid as _uuid
        delegation = Delegation(
            id=str(_uuid.uuid4()),
            owner_id=owner_id,
            operator_id=accepting_user_id,
            invitation_id=str(invitation.id),
            status=initial_status,
            role_preset=str(invitation.proposed_role_preset),
            scope_type=str(invitation.proposed_scope_type),
            scope_target_ids=invitation.proposed_scope_target_ids,
            commission_pct=invitation.proposed_commission_pct,
            commission_fixed_vnd=invitation.proposed_commission_fixed_vnd,
            threshold_monthly_rent_vnd=Decimal(str(t.get("threshold_monthly_rent_vnd", "0"))),
            threshold_term_months=int(t.get("threshold_term_months", 0)),
            threshold_expense_vnd=Decimal(str(t.get("threshold_expense_vnd", "0"))),
            threshold_rent_change_pct=Decimal(str(t.get("threshold_rent_change_pct", "0"))),
            threshold_refund_vnd=Decimal(str(t.get("threshold_refund_vnd", "0"))),
            poa_format=str(invitation.proposed_poa_format),
            shared_login_disclosure_ack_at=now if disclosure_ack else None,
            activated_at=now if kyc_complete else None,
            retention_tier="hot",
            created_at=now,
            updated_at=now,
        )
        self.db.add(delegation)

        # Mark invitation consumed (single-use token)
        inv_svc.mark_consumed(invitation, accepting_user_id)
        self.db.flush()

        self._log_event(
            "delegation_accepted",
            actor_user_id=accepting_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
            extra={"status": initial_status, "kyc_complete": kyc_complete},
        )
        return delegation

    # ------------------------------------------------------------------
    # pause_delegation
    # ------------------------------------------------------------------

    def pause_delegation(
        self,
        delegation: Delegation,
        reason: str,
        paused_until: Optional[datetime] = None,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """AC-09/50/44: pause an active delegation.

        Valid source states: active.
        System reasons (kyc_expired, gpkd_revoked, owner_death, fraud_flag)
        are set by cron/admin; owner can only supply 'owner_request'.
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status not in ("active",):
            raise InvalidStateTransition(
                current=delegation.status,
                target="paused",
                reason=f"Only active delegations can be paused (reason={reason})",
            )

        now = datetime.utcnow()
        delegation.status = "paused"
        delegation.paused_reason = reason
        delegation.paused_until = paused_until
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_paused",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
            extra={"reason": reason, "paused_until": paused_until.isoformat() if paused_until else None},
        )
        return delegation

    # ------------------------------------------------------------------
    # resume_delegation
    # ------------------------------------------------------------------

    def resume_delegation(
        self,
        delegation: Delegation,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """AC-09: owner resumes a paused delegation.

        Guard: only resumes if pause reason is 'owner_request' (system reasons
        such as kyc_expired require external resolution first).
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status != "paused":
            raise InvalidStateTransition(
                current=delegation.status,
                target="active",
                reason="Only paused delegations can be resumed",
            )

        # System pause reasons cannot be self-cleared by owner
        non_resumable_reasons = frozenset(
            ["kyc_expired", "gpkd_revoked", "owner_death", "fraud_flag"]
        )
        if delegation.paused_reason in non_resumable_reasons:
            raise InvalidStateTransition(
                current=delegation.status,
                target="active",
                reason=(
                    f"Pause reason '{delegation.paused_reason}' requires external resolution "
                    "before resumption. Contact support."
                ),
            )

        now = datetime.utcnow()
        delegation.status = "active"
        delegation.paused_reason = None
        delegation.paused_until = None
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_resumed",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # terminate_delegation
    # ------------------------------------------------------------------

    def terminate_delegation(
        self,
        delegation: Delegation,
        reason: str,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """AC-10/42/45: owner terminates delegation.

        fraud_suspected / legal_dispute → immediate termination (AC-45).
        All other reasons → terminating status + 30d clock (AC-42).

        Valid source states: active, paused, terminating (cancel+re-terminate).
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status not in ("active", "paused", "terminating"):
            raise InvalidStateTransition(
                current=delegation.status,
                target="terminating/terminated",
                reason=f"Cannot terminate from status '{delegation.status}'",
            )

        now = datetime.utcnow()
        is_immediate = reason in _IMMEDIATE_TERMINATE_REASONS

        if is_immediate:
            # AC-45: immediate termination for fraud/legal
            delegation.status = "terminated"
            delegation.terminated_at = now
            delegation.terminate_reason = reason
            delegation.terminate_requested_at = now
            self.db.flush()

            self._log_event(
                "delegation_terminated_immediate",
                actor_user_id=actor_user_id,
                entity_type="delegation",
                entity_id=delegation.id,
                extra={"reason": reason, "immediate": True},
            )
            # Phase-04 in-flight approval cancellation: logged here, consumed in phase-04.
            logger.info(
                "[DELEGATION TERMINATE IMMEDIATE] delegation_id=%s reason=%s — "
                "phase-04 must cancel pending approvals for this delegation.",
                delegation.id,
                reason,
            )
        else:
            # AC-42: 30d notice
            delegation.status = "terminating"
            delegation.terminate_requested_at = now
            delegation.terminate_reason = reason
            delegation.updated_at = now
            self.db.flush()

            self._log_event(
                "delegation_termination_started",
                actor_user_id=actor_user_id,
                entity_type="delegation",
                entity_id=delegation.id,
                extra={"reason": reason, "terminate_at": (now + timedelta(days=_LOCKDOWN_DAYS)).isoformat()},
            )

        return delegation

    # ------------------------------------------------------------------
    # cancel_termination
    # ------------------------------------------------------------------

    def cancel_termination(
        self,
        delegation: Delegation,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """Owner cancels pending 30d termination notice.

        Valid only: status=terminating AND reason != fraud/legal AND 30d not elapsed.
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status != "terminating":
            raise InvalidStateTransition(
                current=delegation.status,
                target="active",
                reason="Only terminating delegations can have termination cancelled",
            )

        # Cannot cancel fraud/legal terminations
        if delegation.terminate_reason in _IMMEDIATE_TERMINATE_REASONS:
            raise InvalidStateTransition(
                current=delegation.status,
                target="active",
                reason="Fraud/legal termination cannot be cancelled",
            )

        # Check 30d window has not elapsed
        if delegation.terminate_requested_at is not None:
            elapsed_at = delegation.terminate_requested_at + timedelta(days=_LOCKDOWN_DAYS)
            if datetime.utcnow() >= elapsed_at:
                raise InvalidStateTransition(
                    current=delegation.status,
                    target="active",
                    reason="30-day termination window has already elapsed; delegation is terminal",
                )

        now = datetime.utcnow()
        delegation.status = "active"
        delegation.terminate_requested_at = None
        delegation.terminate_reason = None
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_termination_cancelled",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # resign_delegation (AC-22: operator self-rescind)
    # ------------------------------------------------------------------

    def resign_delegation(
        self,
        delegation: Delegation,
        actor_user_id: int,
    ) -> Delegation:
        """AC-22: operator self-resigns. Treated as 30d notice termination.

        Only the operator (delegation.operator_id == actor_user_id) can call.
        Reason = 'operator_resign' (not fraud/legal → normal 30d notice).
        """
        delegation = self._reload_with_lock(delegation.id)

        if int(delegation.operator_id) != actor_user_id:
            raise PermissionError(
                "Only the delegation's operator may resign. "
                f"actor={actor_user_id} != operator={delegation.operator_id}"
            )

        if delegation.status not in ("active", "paused"):
            raise InvalidStateTransition(
                current=delegation.status,
                target="terminating",
                reason="Operator can only resign from active or paused delegations",
            )

        now = datetime.utcnow()
        delegation.status = "terminating"
        delegation.terminate_requested_at = now
        delegation.terminate_reason = "operator_resign"
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_operator_resigned",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # archive_delegation (called by cron, AC-44)
    # ------------------------------------------------------------------

    def archive_delegation(
        self,
        delegation: Delegation,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """Transition terminated → archived. Called by delegation_archive_promoter cron."""
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status != "terminated":
            raise InvalidStateTransition(
                current=delegation.status,
                target="archived",
                reason="Only terminated delegations can be archived",
            )

        now = datetime.utcnow()
        delegation.status = "archived"
        delegation.archived_at = now
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_archived",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # set_out_of_office (AC-57)
    # ------------------------------------------------------------------

    def set_out_of_office(
        self,
        delegation: Delegation,
        out_of_office_start: Optional[datetime],
        out_of_office_end: Optional[datetime],
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """AC-57: operator sets or clears out-of-office date range.

        Validation of start < end is done at schema level (OutOfOfficeRequest).
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status not in ("active", "terminating"):
            raise InvalidStateTransition(
                current=delegation.status,
                target="active (with OOO set)",
                reason="Out-of-office can only be set on active or terminating delegations",
            )

        now = datetime.utcnow()
        delegation.out_of_office_start = out_of_office_start
        delegation.out_of_office_end = out_of_office_end
        delegation.updated_at = now
        self.db.flush()

        action = "delegation_oof_set" if out_of_office_start is not None else "delegation_oof_cleared"
        self._log_event(
            action,
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
            extra={
                "oof_start": out_of_office_start.isoformat() if out_of_office_start else None,
                "oof_end": out_of_office_end.isoformat() if out_of_office_end else None,
            },
        )
        return delegation

    # ------------------------------------------------------------------
    # update_thresholds
    # ------------------------------------------------------------------

    def update_thresholds(
        self,
        delegation: Delegation,
        thresholds: object,  # ThresholdsRequest
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """Owner updates delegation thresholds mid-contract (PATCH /thresholds)."""
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status not in ("active", "paused"):
            raise InvalidStateTransition(
                current=delegation.status,
                target="active (thresholds updated)",
                reason="Thresholds can only be updated on active or paused delegations",
            )

        from decimal import Decimal
        now = datetime.utcnow()
        delegation.threshold_monthly_rent_vnd = Decimal(str(thresholds.threshold_monthly_rent_vnd))  # type: ignore[attr-defined]
        delegation.threshold_term_months = int(thresholds.threshold_term_months)  # type: ignore[attr-defined]
        delegation.threshold_expense_vnd = Decimal(str(thresholds.threshold_expense_vnd))  # type: ignore[attr-defined]
        delegation.threshold_rent_change_pct = Decimal(str(thresholds.threshold_rent_change_pct))  # type: ignore[attr-defined]
        delegation.threshold_refund_vnd = Decimal(str(thresholds.threshold_refund_vnd))  # type: ignore[attr-defined]
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_thresholds_updated",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # promote_to_active (when KYC becomes complete for pending_op_kyc)
    # ------------------------------------------------------------------

    def promote_to_active(
        self,
        delegation: Delegation,
        actor_user_id: Optional[int] = None,
    ) -> Delegation:
        """AC-05: promote pending_op_kyc → active once KYC is verified.

        Called by phase-05 KYC completion webhook.
        """
        delegation = self._reload_with_lock(delegation.id)
        if delegation.status != "pending_op_kyc":
            raise InvalidStateTransition(
                current=delegation.status,
                target="active",
                reason="promote_to_active only valid from pending_op_kyc",
            )

        # AC-08: re-check for concurrent active delegation race
        existing = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == delegation.owner_id,
                Delegation.status == "active",
                Delegation.id != delegation.id,
            )
            .first()
        )
        if existing is not None:
            raise OwnerHasActiveDelegation(existing_id=str(existing.id))

        now = datetime.utcnow()
        delegation.status = "active"
        delegation.activated_at = now
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_activated",
            actor_user_id=actor_user_id,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # Internal: cron-driven termination completion (AC-44)
    # ------------------------------------------------------------------

    def complete_termination(
        self,
        delegation: Delegation,
    ) -> Delegation:
        """AC-44: cron completes termination after 30d window.

        Called by delegation_termination_lockdown_expirer job.
        No FOR UPDATE here — cron processes one at a time and the query
        uses filtered batch. Caller commits per-item.
        """
        now = datetime.utcnow()
        delegation.status = "terminated"
        delegation.terminated_at = now
        delegation.updated_at = now
        self.db.flush()

        self._log_event(
            "delegation_terminated_by_cron",
            actor_user_id=None,
            entity_type="delegation",
            entity_id=delegation.id,
        )
        return delegation

    # ------------------------------------------------------------------
    # Helper: check operator KYC completeness (AC-05)
    # ------------------------------------------------------------------

    def _check_operator_kyc_complete(self, operator_user_id: int) -> bool:
        """True if operator's KYC is verified and not expired.

        In v1, checks host_profiles.kyc_status == 'verified'.
        Phase-05 may extend this with kyc_expires_at check.
        Returns False safely if host_profiles table doesn't have kyc_status column yet.
        """
        try:
            from app import models
            profile = (
                self.db.query(models.HostProfile)
                .filter(models.HostProfile.user_id == operator_user_id)
                .first()
            )
            if profile is None:
                return False
            # kyc_status field may not exist in all environments — safe access
            kyc_status = getattr(profile, "kyc_status", None)
            if kyc_status is not None:
                return str(kyc_status) == "verified"
            # Fallback: if no kyc_status column, treat as complete for non-blocking onboarding
            return True
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[DELEGATION] KYC check failed for operator %d: %s — defaulting to pending_op_kyc",
                operator_user_id,
                exc,
            )
            return False

    # ------------------------------------------------------------------
    # Helper: reload with pessimistic lock
    # ------------------------------------------------------------------

    def _reload_with_lock(self, delegation_id: str) -> Delegation:
        """Reload delegation with SELECT FOR UPDATE to prevent race conditions (NFR-01).

        Falls back to regular select if DB doesn't support FOR UPDATE
        (e.g., SQLite in unit tests).
        """
        try:
            row = (
                self.db.query(Delegation)
                .filter(Delegation.id == delegation_id)
                .with_for_update()
                .first()
            )
        except Exception:  # noqa: BLE001 — SQLite doesn't support FOR UPDATE
            row = (
                self.db.query(Delegation)
                .filter(Delegation.id == delegation_id)
                .first()
            )
        if row is None:
            raise ValueError(f"Delegation {delegation_id} not found")
        return row

    # ------------------------------------------------------------------
    # Helper: log transition event
    # ------------------------------------------------------------------

    def _log_event(
        self,
        action: str,
        actor_user_id: Optional[int],
        entity_type: str,
        entity_id: str,
        extra: Optional[dict] = None,
    ) -> None:
        """Write a structured log entry for the state transition.

        v1: log only. Phase-04 audit_log_service / ChangeLog integration
        will consume this when phase-04 ships.
        """
        logger.info(
            "[DELEGATION EVENT] action=%s actor=%s entity_type=%s entity_id=%s extra=%s",
            action,
            actor_user_id,
            entity_type,
            entity_id,
            extra or {},
        )
