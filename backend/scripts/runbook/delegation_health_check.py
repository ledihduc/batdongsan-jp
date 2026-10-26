"""Runbook: delegation health check — at-risk delegations (Phase 10).

Lists delegations in potentially problematic states:
  1. paused > 30 days (owner should be notified to take action)
  2. status=terminating (30d lockdown in progress)
  3. status=pending_op_kyc (stuck waiting for operator KYC > 7 days)
  4. paused with reason=disputed_authority (AC-63 dispute pending)

Usage:
  python -m scripts.runbook.delegation_health_check [--dry-run] [--apply] [--paused-days N]

Options:
  --dry-run      List at-risk delegations only; no mutations (DEFAULT).
  --apply        Not applicable for health check; exits with info message.
  --paused-days  Alert threshold for paused delegations (default: 30).

Output:
  stderr: human-readable log.
  stdout: JSON summary with at-risk records grouped by risk category.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import logging
from datetime import datetime, timedelta

logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("delegation_health_check")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Delegation health check — at-risk delegations (Phase 10 runbook)"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", dest="dry_run", action="store_true", default=True)
    mode.add_argument("--apply", dest="dry_run", action="store_false")
    parser.add_argument("--paused-days", type=int, default=30, metavar="N")
    return parser.parse_args()


def _delegation_to_dict(d: object) -> dict:
    """Convert a Delegation ORM row to a plain dict."""
    return {
        "id": str(d.id),  # type: ignore[attr-defined]
        "owner_id": int(d.owner_id),  # type: ignore[attr-defined]
        "operator_id": int(d.operator_id),  # type: ignore[attr-defined]
        "status": str(d.status),  # type: ignore[attr-defined]
        "paused_reason": d.paused_reason,  # type: ignore[attr-defined]
        "terminate_requested_at": (
            d.terminate_requested_at.isoformat()  # type: ignore[attr-defined]
            if d.terminate_requested_at  # type: ignore[attr-defined]
            else None
        ),
        "created_at": d.created_at.isoformat(),  # type: ignore[attr-defined]
        "updated_at": d.updated_at.isoformat(),  # type: ignore[attr-defined]
        "retention_tier": str(d.retention_tier),  # type: ignore[attr-defined]
    }


def main() -> int:
    args = _parse_args()

    if not args.dry_run:
        logger.info(
            "--apply is not applicable for delegation_health_check. "
            "This script is read-only. Use admin API endpoints for mutations."
        )

    logger.info("=== delegation_health_check [DRY-RUN] paused_days_threshold=%d ===",
                args.paused_days)

    if "DATABASE_URL" not in os.environ:
        logger.error("DATABASE_URL env var not set. Aborting.")
        return 1

    try:
        from app.database import SessionLocal
        from app.domain.delegation import Delegation
    except ImportError as exc:
        logger.error("Failed to import app modules: %s", exc)
        return 1

    now = datetime.utcnow()
    paused_threshold = now - timedelta(days=args.paused_days)
    kyc_stuck_threshold = now - timedelta(days=7)

    categories: dict[str, list[dict]] = {
        "paused_long_term": [],
        "terminating_in_lockdown": [],
        "pending_kyc_stuck": [],
        "disputed_authority": [],
    }

    with SessionLocal() as db:
        # 1. Paused > N days
        long_paused = (
            db.query(Delegation)
            .filter(
                Delegation.status == "paused",
                Delegation.updated_at <= paused_threshold,
                Delegation.paused_reason != "disputed_authority",
            )
            .order_by(Delegation.updated_at.asc())
            .all()
        )
        for d in long_paused:
            days_paused = (now - d.updated_at).days
            logger.warning(
                "LONG-PAUSED id=%s owner=%d reason=%s days=%d",
                d.id, d.owner_id, d.paused_reason, days_paused,
            )
            rec = _delegation_to_dict(d)
            rec["days_paused"] = days_paused
            categories["paused_long_term"].append(rec)

        # 2. Terminating (30d lockdown in progress)
        terminating = (
            db.query(Delegation)
            .filter(Delegation.status == "terminating")
            .order_by(Delegation.terminate_requested_at.asc())
            .all()
        )
        for d in terminating:
            days_remaining = None
            if d.terminate_requested_at:
                lockdown_end = d.terminate_requested_at + timedelta(days=30)
                days_remaining = (lockdown_end - now).days
            logger.info(
                "TERMINATING id=%s owner=%d days_remaining=%s",
                d.id, d.owner_id, days_remaining,
            )
            rec = _delegation_to_dict(d)
            rec["days_remaining_in_lockdown"] = days_remaining
            categories["terminating_in_lockdown"].append(rec)

        # 3. Pending KYC > 7 days
        kyc_stuck = (
            db.query(Delegation)
            .filter(
                Delegation.status == "pending_op_kyc",
                Delegation.created_at <= kyc_stuck_threshold,
            )
            .order_by(Delegation.created_at.asc())
            .all()
        )
        for d in kyc_stuck:
            days_waiting = (now - d.created_at).days
            logger.warning(
                "KYC-STUCK id=%s operator=%d days_waiting=%d",
                d.id, d.operator_id, days_waiting,
            )
            rec = _delegation_to_dict(d)
            rec["days_waiting_for_kyc"] = days_waiting
            categories["pending_kyc_stuck"].append(rec)

        # 4. Disputed authority
        disputed = (
            db.query(Delegation)
            .filter(
                Delegation.status == "paused",
                Delegation.paused_reason == "disputed_authority",
            )
            .order_by(Delegation.updated_at.asc())
            .all()
        )
        for d in disputed:
            logger.warning(
                "DISPUTED id=%s owner=%d operator=%d",
                d.id, d.owner_id, d.operator_id,
            )
            categories["disputed_authority"].append(_delegation_to_dict(d))

    total_at_risk = sum(len(v) for v in categories.values())
    logger.info("Total at-risk delegations: %d", total_at_risk)

    summary = {
        "mode": "DRY-RUN",
        "as_of": now.isoformat(),
        "total_at_risk": total_at_risk,
        "counts": {k: len(v) for k, v in categories.items()},
        "categories": categories,
    }

    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
