"""Admin dispute service — Phase 10 (AC-63).

Manages tenant unauthorized-operator dispute review lifecycle:
  - escalate_dispute()  — mark a TenantAuthorityFlag for priority review
  - resolve_dispute()   — admin closes dispute with verdict + optional delegation pause

Dispute model:
  Uses existing 'tenant_authority_flags' table (app.domain.tenant_authority.TenantAuthorityFlag).
  No new table required — the 'status' field is extended via allowed values:
    pending → escalated → valid | invalid
  See AC-63: 48h SLA tracked via (reviewed_at - created_at).

Security: admin_user_id verified at route layer; not re-checked here.
Does NOT commit — caller owns the transaction.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Allowed TenantAuthorityFlag status values extended for phase-10
_PENDING_STATUSES = frozenset(["pending", "escalated"])
_RESOLVED_STATUSES = frozenset(["valid", "invalid"])


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
    """Write ChangeLog row for admin dispute action."""
    from app import models

    payload: dict = {"reason": reason, "admin_action": True}
    if extra:
        payload.update(extra)
    if delegation_id:
        payload["delegation_id"] = delegation_id

    log = models.ChangeLog(
        entity_type="dispute",
        entity_id=target_user_id,
        actor_id=admin_user_id,
        action=action,
        before_json=None,
        after_json=json.dumps(payload),
        on_behalf_of_user_id=target_user_id,
        acted_via_delegation_id=delegation_id,
    )
    db.add(log)
    db.flush()


class AdminDisputeService:
    """Admin operations on tenant authority flags (AC-63 dispute queue).

    Does NOT commit — caller owns the transaction.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # list_disputes
    # ------------------------------------------------------------------

    def list_disputes(self, status: Optional[str] = None) -> list:
        """Return tenant authority flags, optionally filtered by status."""
        from app.domain.tenant_authority import TenantAuthorityFlag

        query = self.db.query(TenantAuthorityFlag)
        if status:
            query = query.filter(TenantAuthorityFlag.status == status)
        return query.order_by(TenantAuthorityFlag.created_at.asc()).all()

    # ------------------------------------------------------------------
    # escalate_dispute
    # ------------------------------------------------------------------

    def escalate_dispute(
        self,
        dispute_id: str,
        admin_user_id: int,
        reason: str,
    ) -> object:
        """Mark a pending dispute for priority review.

        Transitions: pending → escalated (idempotent if already escalated).
        Raises ValueError if dispute is already resolved or not found.
        """
        from app.domain.tenant_authority import TenantAuthorityFlag

        flag = (
            self.db.query(TenantAuthorityFlag)
            .filter(TenantAuthorityFlag.id == dispute_id)
            .with_for_update()
            .first()
        )
        if flag is None:
            raise ValueError(f"Dispute {dispute_id!r} not found")

        if flag.status in _RESOLVED_STATUSES:
            raise ValueError(
                f"Dispute {dispute_id!r} is already resolved (status={flag.status}). "
                "Cannot escalate a resolved dispute."
            )

        flag.status = "escalated"
        self.db.flush()

        _write_admin_change_log(
            self.db,
            admin_user_id=admin_user_id,
            target_user_id=int(flag.reported_operator_user_id),
            action="admin_escalate_dispute",
            delegation_id=flag.delegation_id,
            reason=reason,
            extra={"dispute_id": dispute_id, "tenant_id": int(flag.tenant_id)},
        )

        logger.info(
            "[ADMIN] escalate_dispute dispute_id=%s admin=%d",
            dispute_id,
            admin_user_id,
        )
        return flag

    # ------------------------------------------------------------------
    # resolve_dispute
    # ------------------------------------------------------------------

    def resolve_dispute(
        self,
        dispute_id: str,
        admin_user_id: int,
        outcome: str,
        action: str,
        reason: str,
    ) -> dict:
        """Admin closes a dispute with a verdict.

        Args:
            outcome: 'prima_facie_valid' | 'invalid' | 'requires_evidence'
            action:  'pause_delegation' | 'no_action' | 'request_more_info'
            reason:  Mandatory justification string.

        Returns:
            dict with resolution details + delegation_paused flag.
        """
        from app.domain.tenant_authority import TenantAuthorityFlag

        flag = (
            self.db.query(TenantAuthorityFlag)
            .filter(TenantAuthorityFlag.id == dispute_id)
            .with_for_update()
            .first()
        )
        if flag is None:
            raise ValueError(f"Dispute {dispute_id!r} not found")

        if flag.status in _RESOLVED_STATUSES:
            raise ValueError(
                f"Dispute {dispute_id!r} is already resolved (status={flag.status})."
            )

        now = datetime.utcnow()

        # Map outcome to DB status
        db_status = "valid" if outcome == "prima_facie_valid" else "invalid"
        flag.status = db_status
        flag.reviewed_at = now
        flag.reviewed_by_admin_id = admin_user_id
        self.db.flush()

        delegation_paused = False

        # If outcome valid + action=pause_delegation → pause the correlated delegation
        if action == "pause_delegation" and flag.delegation_id:
            delegation_paused = self._pause_delegation_for_dispute(
                delegation_id=str(flag.delegation_id),
                admin_user_id=admin_user_id,
                reason=reason,
            )

        _write_admin_change_log(
            self.db,
            admin_user_id=admin_user_id,
            target_user_id=int(flag.reported_operator_user_id),
            action="admin_resolve_dispute",
            delegation_id=flag.delegation_id,
            reason=reason,
            extra={
                "dispute_id": dispute_id,
                "outcome": outcome,
                "action": action,
                "delegation_paused": delegation_paused,
            },
        )

        logger.info(
            "[ADMIN] resolve_dispute dispute_id=%s outcome=%s action=%s delegation_paused=%s",
            dispute_id,
            outcome,
            action,
            delegation_paused,
        )

        return {
            "dispute_id": dispute_id,
            "outcome": outcome,
            "action": action,
            "reason": reason,
            "resolved_at": now,
            "delegation_paused": delegation_paused,
        }

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _pause_delegation_for_dispute(
        self,
        delegation_id: str,
        admin_user_id: int,
        reason: str,
    ) -> bool:
        """Pause delegation due to tenant dispute (AC-63).

        Returns True if delegation was paused, False if not found / already paused.
        """
        from app.domain.delegation import Delegation

        delegation = (
            self.db.query(Delegation)
            .filter(Delegation.id == delegation_id)
            .with_for_update()
            .first()
        )
        if delegation is None or delegation.status != "active":
            logger.warning(
                "[ADMIN] dispute pause: delegation %s not active (status=%s)",
                delegation_id,
                getattr(delegation, "status", "not_found"),
            )
            return False

        delegation.status = "paused"
        delegation.paused_reason = "disputed_authority"
        delegation.updated_at = datetime.utcnow()
        self.db.flush()

        logger.info(
            "[ADMIN] paused delegation_id=%s for disputed_authority dispute admin=%d",
            delegation_id,
            admin_user_id,
        )
        return True
