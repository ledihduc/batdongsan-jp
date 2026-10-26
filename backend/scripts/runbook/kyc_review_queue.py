"""Runbook: KYC review queue for operator business profiles (US-A3).

Lists pending KYC submissions and reports SLA compliance.
48h SLA target: admin must review within 48h of submission (BA §10.7).

Usage:
  python -m scripts.runbook.kyc_review_queue [--dry-run] [--apply] [--limit N]

Options:
  --dry-run   List pending KYC submissions only; no mutations (DEFAULT).
  --apply     Not supported for KYC (requires human document review).
              Script exits with message if --apply provided.
  --limit N   Maximum records to list (default: 50).

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
from datetime import datetime

logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("kyc_review_queue")

_SLA_HOURS = 48
_SLA_WARNING_HOURS = 36


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="KYC review queue for operator business profiles (US-A3 runbook)"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", dest="dry_run", action="store_true", default=True)
    mode.add_argument("--apply", dest="dry_run", action="store_false")
    parser.add_argument("--limit", type=int, default=50, metavar="N")
    return parser.parse_args()


def _sla_status(created_at: datetime, now: datetime) -> str:
    hours = (now - created_at).total_seconds() / 3600
    if hours > _SLA_HOURS:
        return "breach"
    if hours > _SLA_WARNING_HOURS:
        return "warning"
    return "ok"


def main() -> int:
    args = _parse_args()

    if not args.dry_run:
        logger.error(
            "--apply is not supported for kyc_review_queue. "
            "KYC approval requires human document review. "
            "Use the admin API endpoint /admin/kyc/operator-business/{id}/approve instead."
        )
        return 2

    logger.info("=== kyc_review_queue [DRY-RUN] limit=%d ===", args.limit)

    if "DATABASE_URL" not in os.environ:
        logger.error("DATABASE_URL env var not set. Aborting.")
        return 1

    try:
        from app.database import SessionLocal
        from app.domain.operator_business import OperatorBusinessProfile
    except ImportError as exc:
        logger.error("Failed to import app modules: %s", exc)
        return 1

    now = datetime.utcnow()
    results: list[dict] = []

    with SessionLocal() as db:
        pending = (
            db.query(OperatorBusinessProfile)
            .filter(OperatorBusinessProfile.verification_status == "pending")
            .order_by(OperatorBusinessProfile.created_at.asc())
            .limit(args.limit)
            .all()
        )

        logger.info("Found %d pending KYC submissions", len(pending))

        for profile in pending:
            sla = _sla_status(profile.created_at, now)
            hours = (now - profile.created_at).total_seconds() / 3600
            level = logging.WARNING if sla in ("breach", "warning") else logging.INFO
            logger.log(
                level,
                "profile_id=%d user_id=%d business=%r sla=%s hours=%.1f",
                profile.id,
                profile.user_id,
                profile.business_name,
                sla,
                hours,
            )
            results.append(
                {
                    "profile_id": profile.id,
                    "user_id": int(profile.user_id),
                    "business_name": profile.business_name,
                    "verification_status": profile.verification_status,
                    "created_at": profile.created_at.isoformat(),
                    "hours_pending": round(hours, 1),
                    "sla_status": sla,
                }
            )

    summary = {
        "mode": "DRY-RUN",
        "total_pending": len(results),
        "sla_breach_count": sum(1 for r in results if r["sla_status"] == "breach"),
        "sla_warning_count": sum(1 for r in results if r["sla_status"] == "warning"),
        "records": results,
    }

    print(json.dumps(summary, indent=2, default=str))
    logger.info("Done. breach=%d warning=%d ok=%d",
                summary["sla_breach_count"],
                summary["sla_warning_count"],
                len(results) - summary["sla_breach_count"] - summary["sla_warning_count"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
