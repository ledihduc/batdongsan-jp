"""
backfill_geocode.py — geocode tin thiếu lat/lng qua Nominatim nội bộ.

Idempotent + resumable qua cột geocode_status (commit từng tin → kill giữa chừng
chạy lại tiếp đúng chỗ). Throttled để không nghẽn Nominatim dùng chung với planning.
Set lat/lng → trigger DB tự tính geom (không đụng geom trong script).

Chỉ Postgres/PostGIS (cần geom + trigger). Kết quả ngoài bbox VN → đánh 'failed'.

Usage:
    python scripts/backfill_geocode.py --batch 200 --sleep 1.0
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text  # noqa: E402

from app.config import settings  # noqa: E402
from app.database import SessionLocal  # noqa: E402
from app.services import nominatim_proxy  # noqa: E402

log = logging.getLogger("backfill_geocode")


async def _geocode_one(address: str, district: str, city: str) -> tuple[float, float] | None:
    """Forward geocode; thử full address trước, fallback district+city."""
    candidates = [
        ", ".join(x for x in (address, district, city) if x) + ", Việt Nam",
        ", ".join(x for x in (district, city) if x) + ", Việt Nam",
    ]
    for q in candidates:
        if q.strip() == ", Việt Nam":
            continue
        try:
            hits = await nominatim_proxy.search(q, limit=1)
        except Exception as exc:  # noqa: BLE001 — lỗi tạm thời → để 'pending', thử lần sau
            log.warning("nominatim error q=%r: %s", q, exc)
            return None
        if hits:
            lat, lng = float(hits[0]["lat"]), float(hits[0]["lon"])
            south, west, north, east = settings.vn_bbox_full
            if south <= lat <= north and west <= lng <= east:
                return lat, lng
    return None


async def run(batch: int, sleep: float) -> None:
    if not settings.database_url.startswith("postgresql"):
        raise SystemExit("backfill_geocode cần Postgres/PostGIS (geom + trigger).")

    db = SessionLocal()
    processed = geocoded = failed = 0
    try:
        while True:
            rows = db.execute(
                text(
                    """
                    SELECT id, address, city, district FROM houses
                     WHERE geocode_status = 'pending'
                       AND (latitude IS NULL OR longitude IS NULL)
                     ORDER BY id LIMIT :b
                    """
                ),
                {"b": batch},
            ).mappings().all()
            if not rows:
                break

            for r in rows:
                coord = await _geocode_one(
                    r["address"] or "", r["district"] or "", r["city"] or ""
                )
                if coord:
                    lat, lng = coord
                    db.execute(
                        text(
                            """
                            UPDATE houses
                               SET latitude = :lat, longitude = :lng,
                                   geocode_status = 'geocoded', geocoded_at = NOW()
                             WHERE id = :id
                            """
                        ),
                        {"lat": lat, "lng": lng, "id": r["id"]},
                    )
                    geocoded += 1
                else:
                    db.execute(
                        text(
                            "UPDATE houses SET geocode_status='failed', geocoded_at=NOW() "
                            "WHERE id=:id"
                        ),
                        {"id": r["id"]},
                    )
                    failed += 1
                db.commit()  # commit từng tin → resumable
                processed += 1
                await asyncio.sleep(sleep)  # throttle Nominatim

            log.info("batch xong (%d tin) | tổng: %d", len(rows), processed)
    finally:
        db.close()
        log.info(
            "[backfill_geocode] xong: %d tin | geocoded=%d | failed=%d",
            processed, geocoded, failed,
        )


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--batch", type=int, default=200)
    p.add_argument("--sleep", type=float, default=1.0)
    a = p.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(run(a.batch, a.sleep))
