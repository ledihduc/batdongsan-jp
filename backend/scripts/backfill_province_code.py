"""
backfill_province_code.py — chuẩn hoá House.city (free-text) → province_code (slug).

Không gọi mạng; chạy được cả SQLite dev. Idempotent: chỉ xử lý tin có
province_code = NULL. Log tỉ lệ không map được (city rác/sai chính tả).

Usage:
    python scripts/backfill_province_code.py

Requires DATABASE_URL env var. Chạy `alembic upgrade head` (0037) trước.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import models  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.services import provinces_service  # noqa: E402


def run() -> None:
    db = SessionLocal()
    try:
        rows = (
            db.query(models.House)
            .filter(models.House.province_code.is_(None))
            .all()
        )
        mapped = 0
        for h in rows:
            slug = provinces_service.province_slug_for_city(h.city)
            if slug:
                h.province_code = slug
                mapped += 1
        db.commit()
        total = len(rows)
        unmapped = total - mapped
        print(
            f"[backfill_province_code] xử lý {total} tin | "
            f"map được {mapped} | không map {unmapped} "
            f"({(unmapped / total * 100 if total else 0):.1f}% city không khớp tỉnh)"
        )
    finally:
        db.close()


if __name__ == "__main__":
    run()
