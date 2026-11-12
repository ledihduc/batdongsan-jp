"""Fixture dùng chung cho test bản vn (plan 20261027-1102, Phase 13).

SQLite in-memory qua `jp_search_fixtures.make_sqlite_session`; tạo 4 loại hình VN dùng trong
`scripts/data/vn_listings_demo.json` rồi seed 20 tin demo.
"""

from __future__ import annotations

import os
import pathlib

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret-xyz-never-use-in-prod")

from sqlalchemy.orm import Session

from app.models import Category, House

VN_CATEGORY_NAMES: tuple[str, ...] = ("Căn hộ", "Chung cư mini", "Nhà nguyên căn", "Phòng trọ")
VN_DEMO_JSON = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "data" / "vn_listings_demo.json"


def make_vn_categories(db: Session) -> dict[str, int]:
    rows = [Category(name=n, icon="", group_key="stay_long", sort_order=i, is_active=True)
            for i, n in enumerate(VN_CATEGORY_NAMES)]
    db.add_all(rows)
    db.commit()
    return {c.name: c.id for c in rows}


def seed_vn_fixture(db: Session) -> dict[str, int]:
    """Tạo loại hình + seed 20 tin; trả `{tiền tố title: house.id}` cho tin có tag `[..]`."""
    from app.services.vn_demo_seed import load_vn_demo_listings, seed_vn_demo  # noqa: PLC0415

    make_vn_categories(db)
    seed_vn_demo(db, load_vn_demo_listings(VN_DEMO_JSON))
    return {h.title.split(" ", 1)[0]: h.id for h in db.query(House).all() if h.title.startswith("[")}
