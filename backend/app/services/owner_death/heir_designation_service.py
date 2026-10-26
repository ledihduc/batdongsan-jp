"""Heir designation service — AC-58a/b/c.

Responsibilities:
  - designate_heir()           : admin sets heir user_id after legal docs verified
  - create_inherit_view_delegation(): heir gets temporary read-only access
  - record_heir_claim()        : heir claims full ownership (terminates inherit_view)
  - record_heir_terminates()   : heir terminates all delegations
  - extend_heir_window()       : heir requests 30-day extension

Design:
  - Heir gets a virtual 'inherit_view' delegation (read-only, role_preset='owner_view').
  - The inherit_view delegation has a 30-day TTL (paused_until = verified_at + 37d).
  - Claim / terminate / extend are heir actions recorded via audit log.
  - Caller commits; this service only flushes.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation
from app.domain.owner_death import OwnerDeathCertificate

logger = logging.getLogger(__name__)

# 30-day window for heir to act after verification (AC-58a/b/c)
_HEIR_WINDOW_DAYS = 30
# Total pause before 7-day post-verification + heir window
_PAUSE_AFTER_VERIFY_DAYS = 7


class HeirDesignationError(Exception):
    """Base for heir designation errors."""


class HeirAlreadyDesignatedError(HeirDesignationError):
    """Heir is already designated for this death certificate."""


class HeirDesignationService:
    """Heir designation and ownership transfer for owner death workflow."""

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # designate_heir — admin assigns heir after legal docs verified
    # ------------------------------------------------------------------

    def designate_heir(
        self,
        cert: OwnerDeathCertificate,
        heir_user_id: int,
        admin_user_id: int,
    ) -> OwnerDeathCertificate:
        """AC-58b: Admin designates heir user.

        Sets executor_user_id on the death certificate and records the action.
        Can only be called after cert is verified.

        Args:
            cert: the verified OwnerDeathCertificate.
            heir_user_id: the user who will be the heir.
            admin_user_id: admin performing this action.

        Returns: updated certificate.
        """
        if cert.verification_status != "verified":
            raise HeirDesignationError(
                f"Cannot designate heir: certificate {cert.id} is not verified "
                f"(current: {cert.verification_status})"
            )

        cert.executor_user_id = heir_user_id
        cert.executor_onboarded_at = datetime.utcnow()
        self.db.flush()

        logger.info(
            "[HEIR] Designated heir user_id=%d for cert=%s by admin=%d",
            heir_user_id,
            cert.id,
            admin_user_id,
        )
        return cert

    # ------------------------------------------------------------------
    # create_inherit_view_delegation — virtual read-only access for heir
    # ------------------------------------------------------------------

    def create_inherit_view_delegation(
        self,
        cert: OwnerDeathCertificate,
        heir_user_id: int,
        admin_user_id: int,
    ) -> Delegation:
        """AC-58a: Create a temporary read-only 'inherit_view' delegation for the heir.

        This gives the heir access to view all owner data for 30 days.
        The delegation uses role_preset='owner_view', status='paused'
        with paused_reason='heir_review_window' and paused_until set to
        the end of the 30-day window.

        Args:
            cert: the verified OwnerDeathCertificate.
            heir_user_id: the heir user ID.
            admin_user_id: admin creating this delegation.

        Returns: newly created inherit_view Delegation.
        """
        if cert.executor_user_id is None:
            raise HeirDesignationError(
                "Heir must be designated before creating inherit_view delegation. "
                "Call designate_heir() first."
            )

        # Check if an inherit_view delegation already exists for this owner/heir pair
        existing = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == cert.owner_user_id,
                Delegation.operator_id == heir_user_id,
                Delegation.role_preset == "owner_view",
                Delegation.paused_reason == "heir_review_window",
            )
            .first()
        )
        if existing is not None:
            logger.info(
                "[HEIR] inherit_view delegation already exists: %s — skipping creation",
                existing.id,
            )
            return existing

        now = datetime.utcnow()
        window_end = now + timedelta(days=_HEIR_WINDOW_DAYS)

        delegation = Delegation(
            id=str(uuid.uuid4()),
            owner_id=cert.owner_user_id,
            operator_id=heir_user_id,
            invitation_id=None,
            status="paused",
            paused_reason="heir_review_window",
            paused_until=window_end,
            role_preset="owner_view",
            scope_type="all",
            scope_target_ids=None,
            commission_pct=None,
            commission_fixed_vnd=None,
            # Thresholds: set to 0 (read-only, no operations allowed)
            threshold_monthly_rent_vnd=0,
            threshold_term_months=0,
            threshold_expense_vnd=0,
            threshold_rent_change_pct=0,
            threshold_refund_vnd=0,
            poa_format="notarized_pdf",
            shared_login_disclosure_ack_at=now,
            activated_at=None,
            retention_tier="hot",
            created_at=now,
            updated_at=now,
        )
        self.db.add(delegation)
        self.db.flush()

        logger.info(
            "[HEIR] Created inherit_view delegation %s for heir=%d owner=%d window_end=%s",
            delegation.id,
            heir_user_id,
            cert.owner_user_id,
            window_end.isoformat(),
        )
        return delegation

    # ------------------------------------------------------------------
    # record_heir_claim — heir claims ownership
    # ------------------------------------------------------------------

    def record_heir_claim(
        self,
        delegation: Delegation,
        heir_user_id: int,
    ) -> Delegation:
        """AC-58c: Heir claims ownership — marks inherit_view as claimed.

        In v1, this transitions the paused inherit_view delegation to 'terminated'
        and creates an audit record. The actual ownership transfer (updating
        owner_id on all buildings/contracts) is an admin operation in phase-10.

        Args:
            delegation: the inherit_view Delegation.
            heir_user_id: must match delegation.operator_id.

        Returns: updated Delegation with status='terminated'.
        """
        if int(delegation.operator_id) != heir_user_id:
            raise PermissionError(
                f"Only the heir (operator_id={delegation.operator_id}) can claim; "
                f"got user_id={heir_user_id}"
            )

        if delegation.paused_reason != "heir_review_window":
            raise HeirDesignationError(
                "Only inherit_view delegations can be claimed via this method"
            )

        now = datetime.utcnow()
        delegation.status = "terminated"
        delegation.terminated_at = now
        delegation.terminate_reason = "heir_claimed_ownership"
        delegation.updated_at = now
        self.db.flush()

        logger.info(
            "[HEIR] Heir %d claimed ownership on delegation %s at %s",
            heir_user_id,
            delegation.id,
            now.isoformat(),
        )
        return delegation

    # ------------------------------------------------------------------
    # record_heir_terminates — heir terminates all delegations
    # ------------------------------------------------------------------

    def record_heir_terminates_all(
        self,
        owner_user_id: int,
        heir_user_id: int,
    ) -> list[str]:
        """AC-58c: Heir terminates all active/paused delegations for the owner.

        Only terminates delegations with status in (active, paused, terminating).
        The inherit_view delegation itself is NOT terminated (it tracks the heir).

        Returns: list of delegation IDs that were terminated.
        """
        from app.services.delegation.lifecycle_service import DelegationLifecycleService

        target_delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == owner_user_id,
                Delegation.status.in_(["active", "paused", "terminating"]),
                Delegation.paused_reason != "heir_review_window",
            )
            .all()
        )

        terminated_ids: list[str] = []
        svc = DelegationLifecycleService(self.db)

        for d in target_delegations:
            try:
                svc.terminate_delegation(
                    delegation=d,
                    reason="owner_death_heir_termination",
                    actor_user_id=heir_user_id,
                )
                terminated_ids.append(str(d.id))
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "[HEIR] Failed to terminate delegation %s: %s", d.id, exc
                )

        logger.info(
            "[HEIR] Heir %d terminated %d delegations for owner %d",
            heir_user_id,
            len(terminated_ids),
            owner_user_id,
        )
        return terminated_ids

    # ------------------------------------------------------------------
    # extend_heir_window — extend the 30-day review window
    # ------------------------------------------------------------------

    def extend_heir_window(
        self,
        delegation: Delegation,
        heir_user_id: int,
        extension_days: int = 30,
    ) -> Delegation:
        """AC-58c: Heir extends their 30-day review window.

        The system can grant at most one extension per certificate (enforcement
        is left to the route layer via policy; service does the mutation).

        Args:
            delegation: the inherit_view Delegation.
            heir_user_id: must match delegation.operator_id.
            extension_days: additional days (default 30, max 30 per policy).

        Returns: updated Delegation with new paused_until.
        """
        if int(delegation.operator_id) != heir_user_id:
            raise PermissionError(
                f"Only the heir can extend the window; got user_id={heir_user_id}"
            )

        if delegation.paused_reason != "heir_review_window":
            raise HeirDesignationError(
                "Only inherit_view delegations can be extended via this method"
            )

        now = datetime.utcnow()
        current_until = delegation.paused_until or now
        # Extend from max(current_until, now) to avoid shrinking if somehow expired
        base = max(current_until, now)
        new_until = base + timedelta(days=extension_days)

        delegation.paused_until = new_until
        delegation.updated_at = now
        self.db.flush()

        logger.info(
            "[HEIR] Extended window for delegation %s to %s (heir=%d +%dd)",
            delegation.id,
            new_until.isoformat(),
            heir_user_id,
            extension_days,
        )
        return delegation
