"""Runbook: fraud alert review — 24h-window fraud reports (AC-45 / US-A5).

Lists DelegationApproval rows with action_type='fraud_termination' created
in the last 24h window. Reports SLA compliance and operator risk status.

Usage:
  python -m scripts.runbook.fraud_alert_review [--dry-run] [--apply] [--hours N]

Options:
  --dry-run    List fraud reports only; no mutations (DEFAULT).
  --apply      Auto-suspend operators whose fraud_termination approval
               has expired (status=auto_rejected) within last 1h.
               Delegates to FraudTerminationService.check_and_auto_suspend_expired().
  --hours N    Window to look back in hours (default: 24).

Output:
  stderr: human-readable log.
  stdout: JSON summary.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import logging
from datetime import datetime, timedelta

logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("fraud_alert_review")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fraud alert review — 24h window (AC-45 / US-A5 runbook)"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", dest="dry_run", action="store_true", default=True)
    mode.add_argument("--apply", dest="dry_run", action="store_false")
    parser.add_argument("--hours", type=int, default=24, metavar="N")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    mode_label = "DRY-RUN" if args.dry_run else "APPLY"
    logger.info("=== fraud_alert_review [%s] window=%dh ===", mode_label, args.hours)

    if "DATABASE_URL" not in os.environ:
        logger.error("DATABASE_URL env var not set. Aborting.")
        return 1

    try:
        from app.database import SessionLocal
        from app.domain.delegation import DelegationApproval
    except ImportError as exc:
        logger.error("Failed to import app modules: %s", exc)
        return 1

    now = datetime.utcnow()
    cutoff = now - timedelta(hours=args.hours)
    results: list[dict] = []
    suspended_count = 0

    with SessionLocal() as db:
        fraud_approvals = (
            db.query(DelegationApproval)
            .filter(
                DelegationApproval.action_type == "fraud_termination",
                DelegationApproval.created_at >= cutoff,
            )
            .order_by(DelegationApproval.created_at.desc())
            .all()
        )

        logger.info("Found %d fraud reports in last %dh", len(fraud_approvals), args.hours)

        for appr in fraud_approvals:
            hours_pending = (now - appr.created_at).total_seconds() / 3600
            time_to_expire = (appr.expires_at - now).total_seconds() / 3600 if appr.expires_at > now else 0
            sla_status = "expired" if appr.expires_at <= now else (
                "critical" if hours_pending > 20 else ("warning" if hours_pending > 12 else "ok")
            )

            level = logging.WARNING if sla_status in ("expired", "critical") else logging.INFO
            logger.log(
                level,
                "approval_id=%s delegation=%s status=%s sla=%s hours=%.1f ttl_h=%.1f",
                appr.id,
                appr.delegation_id,
                appr.status,
                sla_status,
                hours_pending,
                time_to_expire,
            )

            results.append(
                {
                    "approval_id": str(appr.id),
                    "delegation_id": str(appr.delegation_id),
                    "status": appr.status,
                    "sla_status": sla_status,
                    "hours_pending": round(hours_pending, 1),
                    "expires_at": appr.expires_at.isoformat() if appr.expires_at else None,
                    "created_at": appr.created_at.isoformat(),
                }
            )

        if not args.dry_run:
            # Trigger auto-suspend for recently expired fraud approvals
            try:
                from app.services.approval.fraud_termination_service import FraudTerminationService

                svc = FraudTerminationService(db)
                suspended_count = svc.check_and_auto_suspend_expired()
                db.commit()
                logger.info("APPLY: auto-suspended %d operator delegations", suspended_count)
            except Exception as exc:  # noqa: BLE001
                db.rollback()
                logger.error("APPLY: auto-suspend failed: %s", exc)
                suspended_count = -1

    summary = {
        "mode": mode_label,
        "window_hours": args.hours,
        "total_fraud_reports": len(results),
        "expired_count": sum(1 for r in results if r["sla_status"] == "expired"),
        "critical_count": sum(1 for r in results if r["sla_status"] == "critical"),
        "operators_suspended": suspended_count if not args.dry_run else "dry_run",
        "records": results,
    }

    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
