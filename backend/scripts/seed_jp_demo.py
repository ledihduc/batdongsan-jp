"""Seed / gỡ tin demo Tokyo cho bản jp (plan 20261027-1102, Phase 03).

Usage:
    python scripts/seed_jp_demo.py                       # seed (idempotent)
    python scripts/seed_jp_demo.py --data <file.json>
    python scripts/seed_jp_demo.py --undo                # xoá tin/host/loại hình demo JP

Cần import ga trước (`scripts/import_jp_stations.py`). Chỉ chạy khi REGION=jp.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

_DEFAULT_DATA = Path(__file__).parent / "data" / "jp_listings_tokyo_demo.json"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--data", type=Path, default=_DEFAULT_DATA)
    parser.add_argument("--undo", action="store_true")
    args = parser.parse_args()

    # JWT_SECRET bắt buộc khi import app.config (cùng cách import_jp_stations.py).
    os.environ.setdefault("JWT_SECRET", "seed-script-placeholder")
    from app.config import settings
    from app.database import SessionLocal
    from app.services.jp.demo_seed import load_demo_listings, seed_jp_demo, undo_jp_demo

    if settings.region != "jp":
        print(f"REGION={settings.region!r}: seed demo JP chỉ chạy khi REGION=jp", file=sys.stderr)
        return 2

    db = SessionLocal()
    try:
        if args.undo:
            print(f"removed={undo_jp_demo(db)}")
        else:
            print(seed_jp_demo(db, load_demo_listings(args.data)))
    except (ValueError, KeyError) as exc:  # KeyError = phần tử JSON thiếu khoá bắt buộc
        print(f"Lỗi dữ liệu: {exc!r}", file=sys.stderr)
        return 1
    finally:
        db.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
