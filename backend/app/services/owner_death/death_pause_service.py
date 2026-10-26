"""Death pause service — 7-day system pause on all owner delegations (AC-58).

When a death certificate is verified, ALL active delegations for the owner
must be paused for 7 days. This service coordinates with the lockdown service
(which has pause_for_owner_death()) and the lifecycle service.

Also handles:
  - Checking if the 7-day window has expired → transition to archived if no heir claimed
  - Monitoring all death-paused delegations for expiry (cron job helper)
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation
from app.domain.owner_death import OwnerDeathCertificate

logger = logging.getLogger(__name__)

# 7-day pause window per AC-58
_DEATH_PAUSE_DAYS = 7

# Batch size for expiry checks
_BATCH_SIZE = 200


class DeathPauseService:
    """Coordinates 7-day delegation pause after owner death verification."""

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # pause_all_owner_delegations — called immediately after cert verified
    # ------------------------------------------------------------------

    def pause_all_owner_delegations(
        self,
        cert: OwnerDeathCertificate,
        admin_user_id: Optional[int] = None,
    ) -> list[str]:
        """AC-58: Pause all active delegations for the deceased owner for 7 days.

        Calls lockdown_service.pause_for_owner_death() which mirrors the
        existing GPKD pause pattern.

        Args:
            cert: the verified OwnerDeathCertificate.
            admin_user_id: optional admin who triggered this (for audit).

        Returns: list of delegation IDs that were paused.
        """
        from app.services.delegation.lockdown_service import DelegationLockdownService

        lockdown_svc = DelegationLockdownService(self.db)
        paused_ids = lockdown_svc.pause_for_owner_death(
            owner_user_id=cert.owner_user_id,
            death_cert_id=cert.id,
        )

        logger.info(
            "[DEATH_PAUSE] Paused %d delegations for owner=%d cert=%s",
            len(paused_ids),
            cert.owner_user_id,
            cert.id,
        )
        return paused_ids

    # ------------------------------------------------------------------
    # fetch_expired_death_pauses — for cron job
    # ------------------------------------------------------------------

    def fetch_expired_death_pauses(self) -> list[Delegation]:
        """Return delegations paused for owner_death where 7-day window has expired.

        These should either be:
          - Transitioned to archived (if no heir claimed)
          - Left paused (if heir window is still active)
        """
        cutoff = datetime.utcnow() - timedelta(days=_DEATH_PAUSE_DAYS)
        return (
            self.db.query(Delegation)
            .filter(
                Delegation.status == "paused",
                Delegation.paused_reason == "owner_death",
                Delegation.updated_at <= cutoff,
                # paused_until IS NULL means indefinite — use updated_at as proxy
            )
            .limit(_BATCH_SIZE)
            .all()
        )

    # ------------------------------------------------------------------
    # resolve_expired_pause — cron processes each expired pause
    # ------------------------------------------------------------------

    def resolve_expired_pause(
        self,
        delegation: Delegation,
        heir_designation_active: bool = False,
    ) -> str:
        """Process a delegation whose 7-day death pause window has expired.

        If heir is active (heir_review_window paused delegation exists for this
        owner) → leave paused, just update the paused_until.
        If no heir → transition to terminated → archived.

        Args:
            delegation: the death-paused delegation.
            heir_designation_active: True if an heir window is still active.

        Returns: the action taken ('extended', 'terminated', 'skipped').
        """
        from app.services.delegation.lifecycle_service import DelegationLifecycleService

        svc = DelegationLifecycleService(self.db)

        if heir_designation_active:
            # Heir is reviewing — extend pause another 30 days for heir window
            now = datetime.utcnow()
            delegation.paused_until = now + timedelta(days=30)
            delegation.updated_at = now
            self.db.flush()
            logger.info(
                "[DEATH_PAUSE] Extended death pause for delegation %s (heir active)",
                delegation.id,
            )
            return "extended"

        # No heir — terminate and archive per AC-42
        try:
            svc.terminate_delegation(
                delegation=delegation,
                reason="owner_death_no_heir",
                actor_user_id=None,
            )
            logger.info(
                "[DEATH_PAUSE] Terminated delegation %s after 7d death pause expiry",
                delegation.id,
            )
            return "terminated"
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "[DEATH_PAUSE] Failed to terminate delegation %s: %s", delegation.id, exc
            )
            return "skipped"

    # ------------------------------------------------------------------
    # has_active_heir_window — check if heir window exists for owner
    # ------------------------------------------------------------------

    def has_active_heir_window(self, owner_user_id: int) -> bool:
        """Return True if an active heir_review_window delegation exists for owner."""
        now = datetime.utcnow()
        row = (
            self.db.query(Delegation)
            .filter(
                Delegation.owner_id == owner_user_id,
                Delegation.paused_reason == "heir_review_window",
                Delegation.status == "paused",
                Delegation.paused_until >= now,
            )
            .first()
        )
        return row is not None

    # ------------------------------------------------------------------
    # run_expiry_check — batch cron entry point (called by scheduler)
    # ------------------------------------------------------------------

    def run_expiry_check(self) -> dict:
        """Cron job: check and resolve expired 7-day death pause windows.

        Returns summary dict for logging/monitoring.
        """
        expired = self.fetch_expired_death_pauses()
        results: dict = {"checked": len(expired), "extended": 0, "terminated": 0, "skipped": 0}

        for delegation in expired:
            heir_active = self.has_active_heir_window(int(delegation.owner_id))
            action = self.resolve_expired_pause(delegation, heir_designation_active=heir_active)
            results[action] = results.get(action, 0) + 1

            try:
                self.db.commit()
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "[DEATH_PAUSE] Commit failed for delegation %s: %s", delegation.id, exc
                )
                self.db.rollback()
                results["skipped"] += 1

        logger.info("[DEATH_PAUSE] Expiry check complete: %s", results)
        return results
