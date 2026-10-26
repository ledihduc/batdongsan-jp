"""Archive service — data archive operations at Tier 3 transition (AC-44).

Handles:
  - Soft-archiving delegations (set archived_at, status='archived')
  - Checking dispute_active flag before archiving (R5 risk mitigation)
  - Admin manual archive for immediate cases
  - Idempotency: re-archiving an already-archived delegation is a no-op
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy.orm import Session

from app.domain.delegation import Delegation

logger = logging.getLogger(__name__)

# Batch size for cron jobs
_BATCH_SIZE = 500


class ArchiveService:
    """Manages soft-archive lifecycle for delegations.

    Archiving is a SOFT operation: rows remain in DB, archived_at is set,
    status → 'archived'. Active queries exclude archived rows via status filter.
    Admin can still query archived rows for compliance.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    # ------------------------------------------------------------------
    # archive_delegation — single delegation (admin or cron)
    # ------------------------------------------------------------------

    def archive_delegation(
        self,
        delegation: Delegation,
        actor_user_id: Optional[int] = None,
        force: bool = False,
    ) -> tuple[Delegation, str]:
        """Soft-archive a single terminated delegation.

        Checks:
          - Already archived → no-op (idempotent)
          - Status must be 'terminated' (cannot skip to archived)
          - dispute_active check (R5 mitigation): skip if delegation has active dispute
            (checked via a loose attribute; if column doesn't exist, proceeds safely)

        Args:
            delegation: the Delegation ORM object.
            actor_user_id: user triggering archive (None for cron).
            force: if True, bypass dispute_active check (admin override).

        Returns: tuple of (updated Delegation, action: 'archived'|'already_archived'|'skipped').
        """
        # Idempotency: already archived → no-op
        if delegation.status == "archived" and delegation.archived_at is not None:
            return delegation, "already_archived"

        if delegation.status != "terminated":
            logger.warning(
                "[ARCHIVE] Cannot archive delegation %s with status '%s' (need 'terminated')",
                delegation.id,
                delegation.status,
            )
            return delegation, "skipped"

        # R5 risk: skip if active legal dispute (attribute may not exist in all versions)
        if not force:
            dispute_active = getattr(delegation, "dispute_active", False)
            if dispute_active:
                logger.info(
                    "[ARCHIVE] Skipping delegation %s — dispute_active=True", delegation.id
                )
                return delegation, "skipped"

        now = datetime.utcnow()
        delegation.status = "archived"
        delegation.archived_at = now
        delegation.updated_at = now
        self.db.flush()

        logger.info(
            "[ARCHIVE] Archived delegation %s actor=%s", delegation.id, actor_user_id
        )
        return delegation, "archived"

    # ------------------------------------------------------------------
    # run_archive_batch — cron job: archive delegations 30d post-terminate
    # ------------------------------------------------------------------

    def run_archive_batch(self) -> dict:
        """Cron job: archive terminated delegations after 30-day window.

        Fetches up to _BATCH_SIZE eligible delegations and archives them.
        Returns summary for monitoring.
        """
        cutoff = datetime.utcnow() - timedelta(days=30)
        delegations = (
            self.db.query(Delegation)
            .filter(
                Delegation.status == "terminated",
                Delegation.terminated_at <= cutoff,
                Delegation.archived_at.is_(None),
            )
            .limit(_BATCH_SIZE)
            .all()
        )

        stats: dict = {"checked": len(delegations), "archived": 0, "skipped": 0}

        for d in delegations:
            _, action = self.archive_delegation(d)
            if action == "archived":
                stats["archived"] += 1
                try:
                    self.db.commit()
                except Exception as exc:  # noqa: BLE001
                    logger.error("[ARCHIVE] Commit failed for %s: %s", d.id, exc)
                    self.db.rollback()
                    stats["skipped"] += 1
            else:
                stats["skipped"] += 1

        logger.info("[ARCHIVE] Batch complete: %s", stats)
        return stats

    # ------------------------------------------------------------------
    # restore_from_archive — admin restores (for audit/dispute purposes)
    # ------------------------------------------------------------------

    def restore_from_archive(
        self,
        delegation: Delegation,
        admin_user_id: int,
        restore_reason: str,
    ) -> Delegation:
        """Admin restores an archived delegation to 'terminated' for dispute resolution.

        Args:
            delegation: the archived Delegation.
            admin_user_id: admin performing restoration.
            restore_reason: required reason for audit trail.

        Returns: updated Delegation with status='terminated'.
        """
        if delegation.status != "archived":
            raise ValueError(
                f"Cannot restore non-archived delegation {delegation.id} "
                f"(current status: {delegation.status})"
            )

        if not restore_reason or not restore_reason.strip():
            raise ValueError("restore_reason is required for audit compliance")

        now = datetime.utcnow()
        delegation.status = "terminated"
        delegation.archived_at = None
        delegation.updated_at = now
        self.db.flush()

        logger.info(
            "[ARCHIVE] Restored delegation %s from archive. admin=%d reason=%s",
            delegation.id,
            admin_user_id,
            restore_reason,
        )
        return delegation
