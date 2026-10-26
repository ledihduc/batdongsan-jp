"""Fraud termination service — 24h SLA monitor (Phase 04).

AC-43b: when operator reports fraud on a tenant/delegation:
  1. Fraud report created → approval with action_type='fraud_termination',
     sla_class='fraud_termination_24h', lockdown_fraud_termination=True
  2. Escalation ladder: 4h push+email, 12h SMS, 20h admin, 24h auto-reject
  3. If owner approves → delegation terminated immediately (override 30d notice)
  4. If auto-rejected (24h elapsed) → operator suspended across ALL their delegations

Separate from regular approval flow because:
  - Different SLA class (24h vs 72h)
  - Different escalation gates (4h/12h/20h)
  - Different auto-reject consequence (operator suspend, not just entity rejection)
  - Allowed during lockdown (whitelisted in AC-43 lockdown check)
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation, DelegationApproval
from app.services.actor_context import ActorContext
from app.services.approval.approval_service import ApprovalService

logger = logging.getLogger(__name__)

# 24h SLA for fraud termination approval
_FRAUD_SLA_HOURS = 24

# Auto-suspend after 24h no-action (AC-50b pattern)
_OPERATOR_SUSPEND_AFTER_FRAUD_TIMEOUT = True


class FraudTerminationService:
    """Manages fraud termination approval lifecycle with 24h SLA.

    Does NOT commit — caller owns the transaction.
    """

    def __init__(self, db: Session) -> None:
        self.db = db
        self.approval_svc = ApprovalService(db)

    # ------------------------------------------------------------------
    # report_fraud() — operator reports fraud on a delegation
    # ------------------------------------------------------------------

    def report_fraud(
        self,
        actor_ctx: ActorContext,
        delegation: Delegation,
        fraud_reason: str,
        evidence_urls: Optional[list[str]] = None,
    ) -> DelegationApproval:
        """Operator reports fraud, triggering fraud_termination approval.

        Creates approval with:
          - action_type='fraud_termination'
          - sla_class='fraud_termination_24h'
          - lockdown_fraud_termination=True (AC-43b)

        The approval is visible to the owner for action within 24h.
        If no action: auto-rejected → operator suspended.

        Args:
            actor_ctx: operator's ActorContext
            delegation: active Delegation row
            fraud_reason: description of the fraud
            evidence_urls: optional list of evidence URLs/paths

        Returns:
            DelegationApproval created for this fraud report
        """
        payload = {
            "fraud_reason": fraud_reason,
            "evidence_urls": evidence_urls or [],
            "reported_by": actor_ctx.actor_user_id,
            "reported_at": datetime.utcnow().isoformat(),
            "delegation_id": str(delegation.id),
        }

        approval = self.approval_svc.create(
            delegation=delegation,
            action_type="fraud_termination",
            action_payload=payload,
            entity_type="delegation",
            entity_id=None,
            sla_class="fraud_termination_24h",
            lockdown_fraud_termination=True,
        )

        logger.info(
            "[FRAUD TERM] Report created approval_id=%s delegation_id=%s operator=%d",
            approval.id,
            delegation.id,
            actor_ctx.actor_user_id,
        )

        return approval

    # ------------------------------------------------------------------
    # check_and_auto_suspend() — called by fraud_24h cron job
    # ------------------------------------------------------------------

    def check_and_auto_suspend_expired(self) -> int:
        """Auto-suspend operators for fraud_termination approvals that expired without decision.

        For each approval with:
          - action_type='fraud_termination'
          - status='auto_rejected' (just set by auto_reject_expired job)
          - lockdown_fraud_termination=True

        Suspend operator across ALL their active delegations (AC-50b pattern).
        Returns count of operators suspended.
        """
        now = datetime.utcnow()
        # Find recently auto-rejected fraud termination approvals (within last hour)
        recently_expired = (
            self.db.query(DelegationApproval)
            .filter(
                DelegationApproval.action_type == "fraud_termination",
                DelegationApproval.status == "auto_rejected",
                DelegationApproval.lockdown_fraud_termination.is_(True),
                # Only process those decided in last hour (avoid re-processing old ones)
                DelegationApproval.decided_at >= now - timedelta(hours=1),
            )
            .all()
        )

        suspended_count = 0
        for approval in recently_expired:
            try:
                count = self._suspend_operator_delegations(
                    operator_id=int(approval.requester_user_id),
                    reason="fraud_report_timeout",
                )
                suspended_count += count
                logger.info(
                    "[FRAUD TERM] Auto-suspended operator=%d across %d delegations "
                    "due to 24h timeout on approval_id=%s",
                    approval.requester_user_id,
                    count,
                    approval.id,
                )
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "[FRAUD TERM] Failed to suspend operator for approval_id=%s: %s",
                    approval.id,
                    exc,
                    exc_info=True,
                )

        if suspended_count > 0:
            self.db.flush()

        return suspended_count

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _suspend_operator_delegations(
        self, operator_id: int, reason: str
    ) -> int:
        """Pause operator across ALL their active delegations.

        Similar to AC-50b (KYC expiry pause) but triggered by fraud timeout.
        Returns count of delegations paused.
        """
        active_delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.operator_id == operator_id,
                Delegation.status == "active",
            )
            .all()
        )

        now = datetime.utcnow()
        count = 0
        for delegation in active_delegations:
            delegation.status = "paused"
            delegation.paused_reason = "fraud_flag"
            delegation.updated_at = now
            count += 1

        logger.info(
            "[FRAUD TERM] Suspended operator_id=%d across %d delegations reason=%s",
            operator_id,
            count,
            reason,
        )
        return count
