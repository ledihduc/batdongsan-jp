"""Seed / gỡ 20 tin demo VN cho bản vn (plan 20261027-1102, Phase 13).

Usage:
    python scripts/seed_vn_demo.py                       # seed (idempotent)
    python scripts/seed_vn_demo.py --data <file.json>
    python scripts/seed_vn_demo.py --undo                # xoá wishlist trỏ tin demo, tin, host demo

Loại hình phải có sẵn (migration 0074). Chỉ chạy khi REGION=vn:
    $DC exec -T -e REGION=vn -e PYTHONPATH=/app backend python scripts/seed_vn_demo.py
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_DEFAULT_DATA = Path(__file__).parent / "data" / "vn_listings_demo.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=_DEFAULT_DATA)
    parser.add_argument("--undo", action="store_true")
    args = parser.parse_args()

    # JWT_SECRET bắt buộc khi import app.config (cùng cách import_jp_stations.py).
    os.environ.setdefault("JWT_SECRET", "seed-script-placeholder")
    from app.config import settings
    from app.database import SessionLocal
    from app.services.vn_demo_seed import load_vn_demo_listings, seed_vn_demo, undo_vn_demo

    if settings.region != "vn":
        print(f"REGION={settings.region!r}: seed demo VN chỉ chạy khi REGION=vn", file=sys.stderr)
        return 2

    db = SessionLocal()
    try:
        if args.undo:
            print(f"removed={undo_vn_demo(db)}")
        else:
            print(seed_vn_demo(db, load_vn_demo_listings(args.data)))
    except (ValueError, KeyError) as exc:  # KeyError = phần tử JSON thiếu khoá bắt buộc
        print(f"Lỗi dữ liệu: {exc!r}", file=sys.stderr)
        return 1
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
