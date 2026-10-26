"""
seed_dev.py — CLI wrapper for app.seed.run().

Usage:
    python scripts/seed_dev.py

Requires DATABASE_URL env var pointing to a running Postgres instance
(run `alembic upgrade head` first to create tables).

Idempotent: calling multiple times will NOT create duplicate data.
"""

from __future__ import annotations

import sys
import os

# Allow imports from the backend root (app.*)
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main() -> None:
    """Seed dev data into the database specified by DATABASE_URL."""
    try:
        from app.database import SessionLocal
        from app.seed import run
    except ImportError as e:
        print(f"[seed_dev] Import error: {e}")
        print("[seed_dev] Make sure DATABASE_URL is set and requirements are installed.")
        sys.exit(1)

    try:
        with SessionLocal() as db:
            run(db)
        print("[seed_dev] Seed completed successfully.")
    except Exception as e:
        print(f"[seed_dev] Seed failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
