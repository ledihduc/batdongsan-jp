"""Admin delegation action service — Phase 10.

Orchestrates admin write-path operations:
  - force_revoke_delegation()   — US-A2 / AC-45 admin override (court order)
  - suspend_operator()          — global operator suspension (all active delegations)
  - reinstate_operator()        — reverse suspend (resumes admin_suspend paused delegations)

All mutations:
  1. Wrap the corresponding phase-03 delegation lifecycle service.
  2. Write a ChangeLog row with action='admin_*', actor_id=admin_user_id,
     on_behalf_of_user_id=target_user_id, acted_via_delegation_id=delegation_id.
  3. Do NOT commit — caller owns the transaction.

Security: caller must be role=admin (enforced at route level, not here).
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation

logger = logging.getLogger(__name__)


def _write_admin_change_log(
    db: Session,
    *,
    admin_user_id: int,
    target_user_id: int,
    action: str,
    delegation_id: Optional[str] = None,
    reason: str,
    extra: Optional[dict] = None,
) -> None:
    """Write a ChangeLog row for an admin action.

    Follows phase-02 dual-identity convention:
      actor_id            = admin_user_id
      on_behalf_of_user_id = target_user_id (the user acted upon)
      action              = 'admin_<verb>'  (prefixed per phase-10 spec)
    """
    from app import models

    extra_payload = {"reason": reason, "admin_action": True}
    if extra:
        extra_payload.update(extra)
    if delegation_id:
        extra_payload["target_delegation_id"] = delegation_id

    log = models.ChangeLog(
        entity_type="delegation" if delegation_id else "user",
        entity_id=int(delegation_id.replace("-", "")[:8], 16) if delegation_id else target_user_id,
        actor_id=admin_user_id,
        action=action,
        before_json=None,
        after_json=json.dumps(extra_payload),
        on_behalf_of_user_id=target_user_id,
        acted_via_delegation_id=delegation_id,
    )
    db.add(log)
    db.flush()


class AdminDelegationActions:
    """Admin write-path operations on delegations and operators.

    Does NOT commit — caller owns the transaction.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # force_revoke_delegation
    # ------------------------------------------------------------------

    def force_revoke_delegation(
        self,
        delegation_id: str,
        admin_user_id: int,
        reason: str,
        immediate: bool = True,
    ) -> Delegation:
        """Admin force-revokes a delegation (AC-45 override, court order).

        For all non-archived delegations: terminates immediately regardless
        of 30d notice period.

        Writes ChangeLog: action='admin_force_revoke'.
        Does NOT commit.

        Args:
            delegation_id: target delegation UUID.
            admin_user_id: authenticated admin's user ID.
            reason: mandatory reason string (court order, fraud, etc.).
            immediate: True (always for admin path) — bypass 30d notice.

        Returns:
            Updated Delegation in 'terminated' status.

        Raises:
            ValueError: delegation not found or already archived.
        """
        delegation = (
            self.db.query(Delegation)
            .filter(Delegation.id == delegation_id)
            .with_for_update()
            .first()
        )
        if delegation is None:
            raise ValueError(f"Delegation {delegation_id!r} not found")

        if delegation.status == "archived":
            raise ValueError(
                f"Delegation {delegation_id!r} is already archived — cannot force-revoke"
            )

        now = datetime.utcnow()
        previous_status = delegation.status

        # Admin force-revoke: immediate regardless of reason
        delegation.status = "terminated"
        delegation.terminated_at = now
        delegation.terminate_reason = "admin_force_revoke"
        delegation.terminate_requested_at = now
        delegation.updated_at = now
        self.db.flush()

        _write_admin_change_log(
            self.db,
            admin_user_id=admin_user_id,
            target_user_id=int(delegation.owner_id),
            action="admin_force_revoke",
            delegation_id=delegation_id,
            reason=reason,
            extra={
                "previous_status": previous_status,
                "immediate": immediate,
                "target_operator_id": int(delegation.operator_id),
            },
        )

        logger.info(
            "[ADMIN] force_revoke delegation_id=%s admin=%d previous_status=%s reason=%r",
            delegation_id,
            admin_user_id,
            previous_status,
            reason,
        )
        return delegation

    # ------------------------------------------------------------------
    # suspend_operator
    # ------------------------------------------------------------------

    def suspend_operator(
        self,
        operator_user_id: int,
        admin_user_id: int,
        reason: str,
    ) -> int:
        """Globally suspend an operator — pause all their active delegations.

        Sets paused_reason='admin_suspend' on each active delegation.
        Different from per-delegation pause: affects ALL delegations.

        Writes ChangeLog: action='admin_suspend_operator' per delegation paused,
        plus one user-level log entry.

        Returns:
            count of delegations paused.
        """
        active_delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.operator_id == operator_user_id,
                Delegation.status == "active",
            )
            .with_for_update()
            .all()
        )

        now = datetime.utcnow()
        count = 0
        for delegation in active_delegations:
            delegation.status = "paused"
            delegation.paused_reason = "admin_suspend"
            delegation.updated_at = now
            count += 1

            _write_admin_change_log(
                self.db,
                admin_user_id=admin_user_id,
                target_user_id=operator_user_id,
                action="admin_suspend_operator",
                delegation_id=str(delegation.id),
                reason=reason,
                extra={"owner_id": int(delegation.owner_id)},
            )

        self.db.flush()

        logger.info(
            "[ADMIN] suspend_operator operator_id=%d admin=%d delegations_paused=%d reason=%r",
            operator_user_id,
            admin_user_id,
            count,
            reason,
        )
        return count

    # ------------------------------------------------------------------
    # reinstate_operator
    # ------------------------------------------------------------------

    def reinstate_operator(
        self,
        operator_user_id: int,
        admin_user_id: int,
        reason: str,
    ) -> int:
        """Reinstate a suspended operator — resume delegations paused for 'admin_suspend'.

        Only resumes delegations with paused_reason='admin_suspend'.
        System-pause reasons (kyc_expired, gpkd_revoked, owner_death, fraud_flag)
        are NOT touched — they require their own resolution flows.

        Writes ChangeLog: action='admin_reinstate_operator' per delegation resumed.

        Returns:
            count of delegations reinstated.
        """
        admin_paused = (
            self.db.query(Delegation)
            .filter(
                Delegation.operator_id == operator_user_id,
                Delegation.status == "paused",
                Delegation.paused_reason == "admin_suspend",
            )
            .with_for_update()
            .all()
        )

        now = datetime.utcnow()
        count = 0
        for delegation in admin_paused:
            delegation.status = "active"
            delegation.paused_reason = None
            delegation.paused_until = None
            delegation.updated_at = now
            count += 1

            _write_admin_change_log(
                self.db,
                admin_user_id=admin_user_id,
                target_user_id=operator_user_id,
                action="admin_reinstate_operator",
                delegation_id=str(delegation.id),
                reason=reason,
                extra={"owner_id": int(delegation.owner_id)},
            )

        self.db.flush()

        logger.info(
            "[ADMIN] reinstate_operator operator_id=%d admin=%d delegations_reinstated=%d reason=%r",
            operator_user_id,
            admin_user_id,
            count,
            reason,
        )
        return count
