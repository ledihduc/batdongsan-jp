"""One-shot JP station data importer from 駅データ.jp CSV format.

Usage:
    python scripts/import_jp_stations.py --csv scripts/data/jp_stations_tokyo_seed.csv
    python scripts/import_jp_stations.py --csv /path/to/full_ekidata.csv

CSV format (駅データ.jp compatible):
  line_cd, line_name_ja, line_name_en, operator,
  station_cd, station_name_ja, station_name_en, prefecture, latitude, longitude

Idempotent: upserts by ekidata_line_cd and ekidata_station_cd.
Run quarterly when new 駅データ.jp exports are available.

Environment:
  DATABASE_URL must be set (reads from .env if python-dotenv is available).
"""

from __future__ import annotations

import argparse
import csv
import logging
import os
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")


def _setup_env() -> None:
    """Load DATABASE_URL from environment or .env file."""
    if "DATABASE_URL" not in os.environ:
        try:
            from dotenv import load_dotenv  # type: ignore[import]
            env_path = Path(__file__).parent.parent / ".env"
            load_dotenv(env_path)
        except ImportError:
            pass

    if "DATABASE_URL" not in os.environ:
        logger.error(
            "DATABASE_URL not set. Export it or create a .env file in the project root."
        )
        sys.exit(1)

    # JWT_SECRET required for app.config import
    os.environ.setdefault("JWT_SECRET", "import-script-placeholder")


def _parse_decimal(value: str) -> Optional[Decimal]:
    """Parse a decimal string, returning None for empty/invalid values."""
    v = value.strip()
    if not v:
        return None
    try:
        return Decimal(v)
    except InvalidOperation:
        return None


def _parse_int(value: str) -> Optional[int]:
    """Parse an integer string, returning None for empty/invalid values."""
    v = value.strip()
    if not v:
        return None
    try:
        return int(v)
    except ValueError:
        return None


def import_stations(csv_path: str, *, dry_run: bool = False) -> dict:
    """Import station data from CSV into the database.

    Returns a summary dict: {lines_upserted, stations_upserted, errors}.
    """
    _setup_env()

    # Import after env setup to avoid config validation errors
    from app.database import SessionLocal  # noqa: PLC0415
    # Nạp model core (User…) trước: mapper Delegation trỏ 'User' bằng chuỗi, thiếu
    # thì mọi query ORM lỗi "failed to locate a name ('User')".
    import app.models  # noqa: F401,PLC0415
    from app.repositories.jp.transit import StationRepository, TrainLineRepository  # noqa: PLC0415

    db = SessionLocal()
    line_repo = TrainLineRepository(db)
    station_repo = StationRepository(db)

    lines_upserted = 0
    stations_upserted = 0
    errors: list[str] = []

    # Cache line lookups within this import run to avoid N+1 queries
    line_cache: dict[int, int] = {}  # ekidata_line_cd -> internal line.id

    try:
        with open(csv_path, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row_num, row in enumerate(reader, start=2):  # Row 1 = header
                try:
                    line_cd = _parse_int(row.get("line_cd", ""))
                    line_name_ja = row.get("line_name_ja", "").strip()
                    line_name_en = row.get("line_name_en", "").strip() or None
                    operator = row.get("operator", "").strip() or None

                    station_cd = _parse_int(row.get("station_cd", ""))
                    station_name_ja = row.get("station_name_ja", "").strip()
                    station_name_en = row.get("station_name_en", "").strip() or None
                    prefecture = row.get("prefecture", "").strip() or None
                    latitude = _parse_decimal(row.get("latitude", ""))
                    longitude = _parse_decimal(row.get("longitude", ""))

                    if not line_name_ja or not station_name_ja:
                        errors.append(f"Row {row_num}: missing required name fields")
                        continue

                    # Upsert train line (cached)
                    if line_cd not in line_cache:
                        line = line_repo.upsert(
                            name_ja=line_name_ja,
                            ekidata_line_cd=line_cd,
                            name_en=line_name_en,
                            operator=operator,
                        )
                        line_cache[line_cd] = line.id  # type: ignore[index]
                        lines_upserted += 1
                        if dry_run:
                            logger.info("[DRY RUN] Line: %s (cd=%s)", line_name_ja, line_cd)

                    internal_line_id = line_cache.get(line_cd)  # type: ignore[arg-type]

                    # Upsert station
                    station_repo.upsert(
                        name_ja=station_name_ja,
                        ekidata_station_cd=station_cd,
                        line_id=internal_line_id,
                        name_en=station_name_en,
                        prefecture=prefecture,
                        latitude=latitude,
                        longitude=longitude,
                    )
                    stations_upserted += 1
                    if dry_run:
                        logger.info("[DRY RUN] Station: %s (cd=%s)", station_name_ja, station_cd)

                except Exception as exc:  # noqa: BLE001
                    errors.append(f"Row {row_num}: {exc}")
                    logger.warning("Error on row %d: %s", row_num, exc)

        if dry_run:
            logger.info("[DRY RUN] No changes committed.")
            db.rollback()
        else:
            db.commit()
            logger.info(
                "Import complete: %d lines upserted, %d stations upserted, %d errors",
                lines_upserted, stations_upserted, len(errors),
            )

    except Exception as exc:
        db.rollback()
        logger.error("Import failed: %s", exc)
        raise
    finally:
        db.close()

    return {
        "lines_upserted": lines_upserted,
        "stations_upserted": stations_upserted,
        "errors": errors,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import JP station data from 駅データ.jp CSV format"
    )
    parser.add_argument(
        "--csv",
        required=True,
        help="Path to CSV file (駅データ.jp format)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse CSV and log what would be imported without writing to DB",
    )
    args = parser.parse_args()

    if not os.path.exists(args.csv):
        logger.error("CSV file not found: %s", args.csv)
        sys.exit(1)

    result = import_stations(args.csv, dry_run=args.dry_run)

    if result["errors"]:
        logger.warning("%d row errors encountered:", len(result["errors"]))
        for err in result["errors"]:
            logger.warning("  %s", err)

    if result["errors"] and not args.dry_run:
        sys.exit(1)


if __name__ == "__main__":
    main()
