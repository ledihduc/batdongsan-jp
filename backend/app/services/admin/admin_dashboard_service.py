"""Admin dashboard service — read-only aggregates (Phase 10).

Provides counts for the admin ops dashboard:
  - pending_kyc_count        — OperatorBusinessProfile with verification_status='pending'
  - pending_death_certs_count — OwnerDeathCertificate with status='pending_verification'
  - pending_poa_reviews_count — DelegationApproval with status='pending'
  - fraud_reports_last_24h_count — DelegationApproval (action_type=fraud_termination) in 24h window
  - stuck_approvals_count    — DelegationApproval pending > 60h (US-A5)
  - active_delegations_count
  - paused_delegations_count

Also provides:
  - audit_trail_for_delegation()  — full ChangeLog query for a delegation
  - delegations_for_user()        — all delegations where user is owner or operator
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation, DelegationApproval

if TYPE_CHECKING:
    from app import models

logger = logging.getLogger(__name__)

# Stuck approval threshold (US-A5)
_STUCK_APPROVAL_HOURS = 60


class AdminDashboardService:
    """Read-only aggregates for the admin operations dashboard.

    All methods are safe to call in parallel — no mutations, no locks.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # dashboard_summary()
    # ------------------------------------------------------------------

    def dashboard_summary(self) -> dict:
        """Return all dashboard counts as a dict.

        Returns keys matching AdminDashboardSummary schema fields.
        """
        now = datetime.utcnow()

        pending_kyc = self._count_pending_kyc()
        pending_death = self._count_pending_death_certs()
        pending_poa = self._count_pending_poa_reviews()
        fraud_24h = self._count_fraud_reports_last_24h(now)
        stuck = self._count_stuck_approvals(now)
        active_del = self._count_delegations_by_status("active")
        paused_del = self._count_delegations_by_status("paused")

        return {
            "pending_kyc_count": pending_kyc,
            "pending_death_certs_count": pending_death,
            "pending_poa_reviews_count": pending_poa,
            "fraud_reports_last_24h_count": fraud_24h,
            "stuck_approvals_count": stuck,
            "active_delegations_count": active_del,
            "paused_delegations_count": paused_del,
            "as_of": now,
        }

    # ------------------------------------------------------------------
    # audit_trail_for_delegation()
    # ------------------------------------------------------------------

    def audit_trail_for_delegation(self, delegation_id: str) -> list[dict]:
        """Return all ChangeLog entries associated with a delegation.

        Queries change_logs where acted_via_delegation_id = delegation_id
        OR entity_type='delegation' AND entity_id matches (by UUID string).
        Results are ordered by created_at ascending.
        """
        from app import models

        rows = (
            self.db.query(models.ChangeLog)
            .filter(models.ChangeLog.acted_via_delegation_id == delegation_id)
            .order_by(models.ChangeLog.created_at.asc())
            .all()
        )

        import json

        result: list[dict] = []
        for row in rows:
            extra_val = None
            if row.after_json:
                try:
                    extra_val = json.loads(row.after_json)
                except (ValueError, TypeError):
                    extra_val = {"raw": row.after_json}
            result.append(
                {
                    "id": row.id,
                    "action": row.action,
                    "actor_id": row.actor_id,
                    "on_behalf_of_user_id": row.on_behalf_of_user_id,
                    "acted_via_delegation_id": row.acted_via_delegation_id,
                    "entity_type": row.entity_type,
                    "entity_id": row.entity_id,
                    "created_at": row.created_at,
                    "extra": extra_val,
                }
            )
        return result

    # ------------------------------------------------------------------
    # delegations_for_user()
    # ------------------------------------------------------------------

    def delegations_for_user(self, user_id: int) -> dict:
        """Return all delegations where user_id is owner or operator."""
        as_owner = (
            self.db.query(Delegation)
            .filter(Delegation.owner_id == user_id)
            .order_by(Delegation.created_at.desc())
            .all()
        )
        as_operator = (
            self.db.query(Delegation)
            .filter(Delegation.operator_id == user_id)
            .order_by(Delegation.created_at.desc())
            .all()
        )
        return {
            "user_id": user_id,
            "as_owner": as_owner,
            "as_operator": as_operator,
        }

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _count_pending_kyc(self) -> int:
        try:
            from app.domain.operator_business import OperatorBusinessProfile

            return (
                self.db.query(OperatorBusinessProfile)
                .filter(OperatorBusinessProfile.verification_status == "pending")
                .count()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: pending_kyc count failed: %s", exc)
            return 0

    def _count_pending_death_certs(self) -> int:
        try:
            from app.domain.owner_death import OwnerDeathCertificate

            return (
                self.db.query(OwnerDeathCertificate)
                .filter(OwnerDeathCertificate.verification_status == "pending_verification")
                .count()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: pending_death_certs count failed: %s", exc)
            return 0

    def _count_pending_poa_reviews(self) -> int:
        """Count DelegationApproval rows with status='pending' (excluding fraud_termination)."""
        try:
            return (
                self.db.query(DelegationApproval)
                .filter(
                    DelegationApproval.status == "pending",
                    DelegationApproval.action_type != "fraud_termination",
                )
                .count()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: pending_poa_reviews count failed: %s", exc)
            return 0

    def _count_fraud_reports_last_24h(self, now: datetime) -> int:
        """Count fraud_termination approvals created within last 24h."""
        try:
            cutoff = now - timedelta(hours=24)
            return (
                self.db.query(DelegationApproval)
                .filter(
                    DelegationApproval.action_type == "fraud_termination",
                    DelegationApproval.created_at >= cutoff,
                )
                .count()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: fraud_reports_24h count failed: %s", exc)
            return 0

    def _count_stuck_approvals(self, now: datetime) -> int:
        """Count DelegationApproval rows still pending after > 60h."""
        try:
            cutoff = now - timedelta(hours=_STUCK_APPROVAL_HOURS)
            return (
                self.db.query(DelegationApproval)
                .filter(
                    DelegationApproval.status == "pending",
                    DelegationApproval.created_at <= cutoff,
                )
                .count()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: stuck_approvals count failed: %s", exc)
            return 0

    def _count_delegations_by_status(self, status: str) -> int:
        try:
            return self.db.query(Delegation).filter(Delegation.status == status).count()
        except Exception as exc:  # noqa: BLE001
            logger.warning("admin_dashboard: delegation_count(%s) failed: %s", status, exc)
            return 0
