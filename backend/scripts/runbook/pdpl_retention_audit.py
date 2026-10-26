"""Runbook: PDPL 4-tier retention audit (AC-59 / §10.5).

Reports counts per retention tier and optionally dry-runs next transitions.

Usage:
  python -m scripts.runbook.pdpl_retention_audit [--dry-run] [--apply]

Options:
  --dry-run   Show tier distribution + preview next transitions; no mutations (DEFAULT).
  --apply     Trigger daily retention transitions via PdplTierService.run_daily_transitions().

Output:
  stderr: human-readable log.
  stdout: JSON tier distribution + transition preview.

Tiers:
  hot        — recent data, full access (default for new records)
  warm       — 90 days post-termination, accessible
  cold       — 365 days, archived, read-only
  legal_hold — held by court order, never deleted
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import logging
from datetime import datetime

logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("pdpl_retention_audit")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="PDPL 4-tier retention audit (AC-59 runbook)"
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", dest="dry_run", action="store_true", default=True)
    mode.add_argument("--apply", dest="dry_run", action="store_false")
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    mode_label = "DRY-RUN" if args.dry_run else "APPLY"
    logger.info("=== pdpl_retention_audit [%s] ===", mode_label)

    if "DATABASE_URL" not in os.environ:
        logger.error("DATABASE_URL env var not set. Aborting.")
        return 1

    try:
        from app.database import SessionLocal
        from app.services.retention import PdplTierService
    except ImportError as exc:
        logger.error("Failed to import app modules: %s", exc)
        return 1

    with SessionLocal() as db:
        svc = PdplTierService(db)

        # Get current tier distribution
        tier_stats = svc.get_retention_stats()
        logger.info("Current tier distribution:")
        for tier, count in sorted(tier_stats.items()):
            logger.info("  %-12s %d records", tier, count)

        transitions: dict = {}
        if not args.dry_run:
            transitions = svc.run_daily_transitions()
            db.commit()
            logger.info("APPLY: transitions completed: %s", transitions)
        else:
            logger.info("DRY-RUN: skipping actual transitions (use --apply to run)")

    summary = {
        "mode": mode_label,
        "as_of": datetime.utcnow().isoformat(),
        "tier_distribution": tier_stats,
        "transitions_applied": transitions if not args.dry_run else None,
    }

    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
