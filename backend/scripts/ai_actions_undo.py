#!/usr/bin/env python3
"""Gỡ dữ liệu do action ghi AI đã thực thi (plan 20261027-1102 Phase 09, rollback).

Mặc định dry-run (chỉ đếm). `--yes` mới xoá thật. Phạm vi: `--all` hoặc `--since <ISO>`.

  docker compose exec -T -e PYTHONPATH=/app backend python scripts/ai_actions_undo.py --all
  docker compose exec -T -e PYTHONPATH=/app backend python scripts/ai_actions_undo.py --since 2026-11-10T00:00:00+09:00 --yes
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timezone


def _parse_since(value: str) -> datetime:
    dt = datetime.fromisoformat(value)
    if dt.tzinfo is not None:  # DB lưu naive UTC
        dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Undo AI write actions (wishlists / jp_viewings)")
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--all", action="store_true", help="every executed AI action")
    scope.add_argument("--since", type=_parse_since, help="executed at or after this ISO time")
    parser.add_argument("--yes", action="store_true", help="really delete (default: dry-run)")
    args = parser.parse_args(argv)

    # JWT_SECRET bắt buộc khi import app.config (cùng cách import_jp_stations.py).
    os.environ.setdefault("JWT_SECRET", "undo-script-placeholder")
    import app.models  # noqa: F401,PLC0415 — nạp mapper core trước khi query
    from app.database import SessionLocal  # noqa: PLC0415
    from app.services.ai_actions.undo_service import undo_executed_actions  # noqa: PLC0415

    db = SessionLocal()
    try:
        report = undo_executed_actions(db, since=None if args.all else args.since, dry_run=not args.yes)
    finally:
        db.close()
    mode = "deleted" if args.yes else "dry-run (add --yes to delete)"
    print(f"{mode}: wishlists={report.wishlists_deleted} viewings={report.viewings_deleted} "
          f"pending_marked={report.pending_marked}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
