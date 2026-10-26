"""Delegation lockdown service — 30-day termination lockdown enforcement.

AC coverage:
  AC-43: 30d termination lockdown; blocks new commitments via phase-02 decorator.
  AC-44: Background job transitions terminating→terminated after 30d.

This service provides helpers for:
  - Setting lockdown_until on revoke/terminate (used by lifecycle_service)
  - Checking if a delegation is in lockdown (used by phase-02 decorator via
    is_lockdown_blocked in permission_set — no direct DB call needed there)
  - Batch processing for the termination cron job (phase-03 scheduler)

Phase-02 decorator reads delegation.status == 'terminating' directly from DB
and calls is_lockdown_blocked(action) from permission_set. This service
supplements that with date-arithmetic helpers needed by the scheduler.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation

logger = logging.getLogger(__name__)

# 30-day lockdown window per AC-43/44
_LOCKDOWN_DAYS = 30

# Batch size for cron jobs to avoid long-running transactions
_BATCH_SIZE = 500


class DelegationLockdownService:
    """Helpers for 30-day termination lockdown enforcement."""

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # Date helpers
    # ------------------------------------------------------------------

    def compute_termination_date(self, requested_at: datetime) -> datetime:
        """Return the datetime when a 30d termination window expires (AC-43/44)."""
        return requested_at + timedelta(days=_LOCKDOWN_DAYS)

    def is_lockdown_window_elapsed(self, delegation: Delegation) -> bool:
        """True if the 30d window since terminate_requested_at has passed.

        Returns False if terminate_requested_at is None (not in terminating state).
        """
        if delegation.terminate_requested_at is None:
            return False
        expiry = self.compute_termination_date(delegation.terminate_requested_at)
        return datetime.utcnow() >= expiry

    # ------------------------------------------------------------------
    # Batch queries for scheduler
    # ------------------------------------------------------------------

    def fetch_ready_to_terminate(self) -> list[Delegation]:
        """AC-44: fetch delegations ready to transition terminating→terminated.

        Returns up to _BATCH_SIZE rows where the 30d clock has elapsed.
        Uses LIMIT for safety on large datasets.
        """
        # We compute the cutoff in Python to avoid DB dialect differences
        # in date arithmetic. For large datasets, consider pushing to DB.
        cutoff = datetime.utcnow() - timedelta(days=_LOCKDOWN_DAYS)
        return (
            self.db.query(Delegation)
            .filter(
                Delegation.status == "terminating",
                Delegation.terminate_requested_at <= cutoff,
            )
            .limit(_BATCH_SIZE)
            .all()
        )

    def fetch_ready_to_archive(self) -> list[Delegation]:
        """Fetch terminated delegations ready for archive (30d post-terminated_at).

        Used by delegation_archive_promoter cron job.
        """
        cutoff = datetime.utcnow() - timedelta(days=30)
        return (
            self.db.query(Delegation)
            .filter(
                Delegation.status == "terminated",
                Delegation.terminated_at <= cutoff,
                Delegation.archived_at.is_(None),
            )
            .limit(_BATCH_SIZE)
            .all()
        )

    def fetch_kyc_expired_for_pause(self) -> list[Delegation]:
        """AC-50: fetch active delegations where operator's KYC has expired.

        NOTE: This queries delegations directly. In v1 we check
        host_profiles.kyc_expires_at via a join. This is a placeholder
        that returns empty list until phase-05 populates kyc_expires_at.
        """
        from sqlalchemy import text

        # Delegations with status=active where operator's kyc_expires_at < now
        # operator KYC = host_profiles.kyc_expires_at for the operator_id
        # This join may not exist in v1 — safe fallback to empty.
        try:
            now = datetime.utcnow()
            rows = self.db.execute(
                text(
                    "SELECT d.id FROM delegations d "
                    "JOIN host_profiles hp ON hp.user_id = d.operator_id "
                    "WHERE d.status = 'active' "
                    "AND hp.kyc_expires_at IS NOT NULL "
                    "AND hp.kyc_expires_at < :now "
                    "LIMIT :limit"
                ),
                {"now": now, "limit": _BATCH_SIZE},
            ).fetchall()
            if not rows:
                return []
            ids = [str(r[0]) for r in rows]
            return (
                self.db.query(Delegation)
                .filter(Delegation.id.in_(ids))
                .all()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[LOCKDOWN] kyc_expired_for_pause query failed (phase-05 may not be complete): %s",
                exc,
            )
            return []

    def fetch_kyc_grace_lapsed(self) -> list[Delegation]:
        """AC-50: fetch paused delegations where kyc grace period has also lapsed.

        paused_reason='kyc_expired' AND paused_until < now → auto-terminate.
        """
        now = datetime.utcnow()
        return (
            self.db.query(Delegation)
            .filter(
                Delegation.status == "paused",
                Delegation.paused_reason == "kyc_expired",
                Delegation.paused_until < now,
            )
            .limit(_BATCH_SIZE)
            .all()
        )

    def fetch_gpkd_revoked_long_term(self) -> list[Delegation]:
        """AC-61: fetch delegations paused for gpkd_revoked for 15+ days → auto-terminate.

        Joins operator_business_profiles to verify GPKD is still revoked.
        """
        from sqlalchemy import text

        cutoff = datetime.utcnow() - timedelta(days=15)
        try:
            rows = self.db.execute(
                text(
                    "SELECT d.id FROM delegations d "
                    "JOIN operator_business_profiles obp ON obp.user_id = d.operator_id "
                    "WHERE d.status = 'paused' "
                    "AND d.paused_reason = 'gpkd_revoked' "
                    "AND obp.verification_status = 'revoked' "
                    "AND d.updated_at <= :cutoff "
                    "LIMIT :limit"
                ),
                {"cutoff": cutoff, "limit": _BATCH_SIZE},
            ).fetchall()
            if not rows:
                return []
            ids = [str(r[0]) for r in rows]
            return (
                self.db.query(Delegation)
                .filter(Delegation.id.in_(ids))
                .all()
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[LOCKDOWN] gpkd_revoked_long_term query failed: %s", exc
            )
            return []

    # ------------------------------------------------------------------
    # Internal trigger: GPKD revocation auto-pause (AC-44/AC-50b)
    # ------------------------------------------------------------------

    def pause_delegations_for_operator(
        self, operator_user_id: int, reason: str = "gpkd_revoked"
    ) -> list[str]:
        """AC-50b/44: Pause all active delegations for an operator.

        Called when admin marks operator's GPKD as revoked.
        Returns list of delegation IDs that were paused.

        This is a public method (exposed to admin endpoint skeleton in phase-10).
        """
        from app.services.delegation.lifecycle_service import DelegationLifecycleService

        delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.operator_id == operator_user_id,
                Delegation.status == "active",
            )
            .with_for_update()
            .all()
        )

        paused_ids: list[str] = []
        svc = DelegationLifecycleService(self.db)

        for delegation in delegations:
            try:
                svc.pause_delegation(
                    delegation=delegation,
                    reason=reason,
                    paused_until=None,
                    actor_user_id=None,  # system-initiated
                )
                paused_ids.append(str(delegation.id))
                logger.info(
                    "[LOCKDOWN] Paused delegation %s for operator %d reason=%s",
                    delegation.id,
                    operator_user_id,
                    reason,
                )
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "[LOCKDOWN] Failed to pause delegation %s: %s",
                    delegation.id,
                    exc,
                )

        return paused_ids

    # ------------------------------------------------------------------
    # Internal trigger: owner death auto-pause (AC-58)
    # ------------------------------------------------------------------

    def pause_for_owner_death(
        self, owner_user_id: int, death_cert_id: str
    ) -> list[str]:
        """AC-58: Pause all active delegations for an owner after death verified.

        Mirrors pause_delegations_for_operator() but targets the owner side.
        Called by DeathPauseService after admin verifies the death certificate.
        Returns list of delegation IDs that were paused.
        """
        from app.services.delegation.lifecycle_service import DelegationLifecycleService

        delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == owner_user_id,
                Delegation.status == "active",
            )
            .with_for_update()
            .all()
        )

        paused_ids: list[str] = []
        svc = DelegationLifecycleService(self.db)

        for delegation in delegations:
            try:
                svc.pause_delegation(
                    delegation=delegation,
                    reason="owner_death",
                    paused_until=None,  # expiry managed by DeathPauseService cron
                    actor_user_id=None,  # system-initiated
                )
                paused_ids.append(str(delegation.id))
                logger.info(
                    "[LOCKDOWN] Paused delegation %s for owner %d reason=owner_death cert=%s",
                    delegation.id,
                    owner_user_id,
                    death_cert_id,
                )
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "[LOCKDOWN] Failed to pause delegation %s for owner_death: %s",
                    delegation.id,
                    exc,
                )

        return paused_ids
