"""Executor exception service — AC-58d (Pre-launch gate O3).

The executor_exception_service handles the narrow path where a legally designated
executor (next-of-kin with notarized doc) may approve in-flight delegation approvals
that were pending at the moment of the owner's death.

IMPORTANT: This feature is gated behind OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED
environment variable (default False). Gate O3 (legal counsel sign-off) MUST be
cleared before setting this to True in production.

AC-58d scope:
  - Executor may APPROVE pending approvals that were in-flight at moment of death.
  - Executor may NOT submit new approval requests.
  - Limited to urgent items: rent collection, emergency repair < configured threshold.
  - Every executor decision is marked executor_override=True in the audit log.
  - Policy 'executor_may_decide' must be set on OwnerDeathCertificate for this to work.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime
from typing import Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Feature flag: must be explicitly enabled (legal gate O3)
_EXECUTOR_EXCEPTION_FLAG = "OWNER_DEATH_EXECUTOR_EXCEPTION_ENABLED"


def is_executor_exception_enabled() -> bool:
    """True if executor exception is enabled via env flag (gate O3)."""
    return os.getenv(_EXECUTOR_EXCEPTION_FLAG, "false").strip().lower() in (
        "1",
        "true",
        "yes",
    )


class ExecutorExceptionDisabledError(Exception):
    """Raised when executor exception is attempted without gate O3 clearance."""


class ExecutorNotAuthorizedError(Exception):
    """Raised when user is not the designated executor for this certificate."""


class ExecutorExceptionService:
    """Handles executor override decisions for in-flight approvals.

    This service is intentionally minimal — it validates authorization and records
    the override flag. The actual approval state change is handled by the approval
    service (phase-04) which checks the executor_override flag.
    """

    def __init__(self, db: Session) -> None:
        self.db = db

    def check_enabled(self) -> None:
        """Raise ExecutorExceptionDisabledError if gate O3 not cleared."""
        if not is_executor_exception_enabled():
            raise ExecutorExceptionDisabledError(
                f"Executor exception (AC-58d) is disabled. "
                f"Set {_EXECUTOR_EXCEPTION_FLAG}=true only after legal gate O3 is cleared. "
                "Contact the platform legal team."
            )

    def validate_executor(
        self,
        executor_user_id: int,
        cert_executor_user_id: Optional[int],
    ) -> None:
        """Verify that the acting user is the designated executor for the certificate.

        Args:
            executor_user_id: the user requesting the override.
            cert_executor_user_id: the executor_user_id recorded on OwnerDeathCertificate.

        Raises ExecutorNotAuthorizedError if mismatch.
        """
        if cert_executor_user_id is None:
            raise ExecutorNotAuthorizedError(
                "No executor has been designated on this death certificate. "
                "An admin must call designate_heir() first."
            )
        if executor_user_id != cert_executor_user_id:
            raise ExecutorNotAuthorizedError(
                f"User {executor_user_id} is not the designated executor "
                f"(expected: {cert_executor_user_id})"
            )

    def record_executor_decision(
        self,
        approval_id: str,
        executor_user_id: int,
        decision: str,
        cert_id: str,
        notes: Optional[str] = None,
    ) -> dict:
        """Record that an executor made a decision on an in-flight approval.

        This method writes an audit log entry with executor_override=True.
        The actual approval row update must be done by the approval service (phase-04).

        Args:
            approval_id: the delegation_approval ID being decided.
            executor_user_id: the executor user making the decision.
            decision: 'approved' or 'rejected'.
            cert_id: the death certificate ID for cross-reference.
            notes: optional notes from executor.

        Returns: audit metadata dict (for route to include in response).
        """
        if decision not in ("approved", "rejected"):
            raise ValueError(
                f"Invalid decision '{decision}'. Must be 'approved' or 'rejected'."
            )

        now = datetime.utcnow()
        audit_entry = {
            "executor_override": True,
            "decision_by_executor": True,
            "executor_user_id": executor_user_id,
            "death_cert_id": cert_id,
            "approval_id": approval_id,
            "decision": decision,
            "decided_at": now.isoformat(),
            "notes": notes,
        }

        logger.info(
            "[EXECUTOR_EXCEPTION] approval_id=%s executor=%d decision=%s cert=%s notes=%s",
            approval_id,
            executor_user_id,
            decision,
            cert_id,
            notes,
        )
        return audit_entry

    def list_eligible_approvals(
        self,
        owner_user_id: int,
        cert_verified_at: datetime,
    ) -> list[dict]:
        """Return pending approvals that were in-flight at time of death.

        Eligible = delegation_approvals where:
          - delegation.owner_id == owner_user_id
          - approval status was 'pending_owner_approval' at cert_verified_at
          - approval was created BEFORE cert_verified_at (pre-death in-flight)

        This uses a raw query via text() to stay decoupled from phase-04 ORM.
        Returns empty list safely if delegation_approvals table doesn't exist.
        """
        from sqlalchemy import text

        try:
            rows = self.db.execute(
                text(
                    "SELECT da.id, da.delegation_id, da.action_type, da.status, "
                    "da.created_at "
                    "FROM delegation_approvals da "
                    "JOIN delegations d ON d.id = da.delegation_id "
                    "WHERE d.owner_id = :owner_id "
                    "AND da.status = 'pending_owner_approval' "
                    "AND da.created_at <= :verified_at "
                    "ORDER BY da.created_at ASC "
                    "LIMIT 100"
                ),
                {
                    "owner_id": owner_user_id,
                    "verified_at": cert_verified_at,
                },
            ).fetchall()

            return [
                {
                    "id": str(r[0]),
                    "delegation_id": str(r[1]),
                    "action_type": str(r[2]),
                    "status": str(r[3]),
                    "created_at": r[4].isoformat() if r[4] else None,
                }
                for r in rows
            ]
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "[EXECUTOR_EXCEPTION] eligible approvals query failed "
                "(phase-04 may not be complete): %s",
                exc,
            )
            return []
