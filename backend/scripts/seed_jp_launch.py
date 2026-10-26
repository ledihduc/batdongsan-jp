"""seed_jp_launch.py — JP market launch seed data.

Seeds 3 broker orgs (Shinjuku/Shibuya/Setagaya) + 15–20 realistic chintai listings
with geocoded addresses, 敷金/礼金/更新料, layouts (1R/1K/1LDK/2LDK), and
OrgProviderConfig (sandbox payment + esign).

Idempotent: uses ON CONFLICT DO NOTHING / check-then-insert patterns.
Re-running on an already-seeded DB is safe.

Usage:
    python scripts/seed_jp_launch.py --env=staging
    python scripts/seed_jp_launch.py --env=production --confirm-prod

Guards:
    --env=production is refused without --confirm-prod flag.
    Defaults: refuses to run if DATABASE_URL not set.
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import date, datetime, timezone

# Ensure project root is on path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="JP launch seed data — broker orgs + chintai listings",
    )
    parser.add_argument(
        "--env",
        required=True,
        choices=["staging", "production"],
        help="Target environment. Production requires --confirm-prod.",
    )
    parser.add_argument(
        "--confirm-prod",
        action="store_true",
        dest="confirm_prod",
        help="Explicitly confirm production seed. Required when --env=production.",
    )
    return parser.parse_args()


def _guard_env(args: argparse.Namespace) -> None:
    """Refuse production execution without explicit confirmation."""
    if args.env == "production" and not args.confirm_prod:
        print(
            "ERROR: --env=production requires --confirm-prod flag.\n"
            "       Production seed is irreversible. Pass --confirm-prod to proceed.",
            file=sys.stderr,
        )
        sys.exit(1)

    db_url = os.environ.get("DATABASE_URL", "")
    if not db_url:
        print(
            "ERROR: DATABASE_URL environment variable is not set.\n"
            "       Set it to the target database URL before running this script.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"[seed_jp_launch] env={args.env} DB={db_url[:40]}...")


# ── Org definitions ────────────────────────────────────────────────────────────

BROKER_ORGS = [
    {
        "org_id": "org-shinjuku-001",
        "name": "新宿不動産株式会社",
        "prefecture": "東京都",
        "city": "新宿区",
        "email": "admin@shinjuku-realty.jp",
        "phone": "+81-3-1234-0001",
    },
    {
        "org_id": "org-shibuya-002",
        "name": "渋谷住まい株式会社",
        "prefecture": "東京都",
        "city": "渋谷区",
        "email": "admin@shibuya-homes.jp",
        "phone": "+81-3-1234-0002",
    },
    {
        "org_id": "org-setagaya-003",
        "name": "世田谷レジデンス株式会社",
        "prefecture": "東京都",
        "city": "世田谷区",
        "email": "admin@setagaya-residence.jp",
        "phone": "+81-3-1234-0003",
    },
]

# ── Listing definitions ────────────────────────────────────────────────────────
# 5-7 listings per org = 15–20 total.
# Addresses use real postal codes in each ward.
# Rent range: 70,000–220,000 JPY.

LISTINGS = [
    # ── Shinjuku org ──────────────────────────────────────────────────────────
    {
        "org_id": "org-shinjuku-001",
        "title": "新宿三丁目 1LDK 明るい南向き",
        "postal_code": "160-0022",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "新宿三丁目1-14",
        "latitude": 35.6904,
        "longitude": 139.7033,
        "layout": "1LDK",
        "floor_area_sqm": "42.50",
        "building_year": 2018,
        "structure": "RC",
        "floor_number": 8,
        "orientation": "S",
        "monthly_rent_jpy": "145000",
        "management_fee_jpy": "5000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shinjuku-001",
        "title": "西新宿 1K コンパクト単身向け",
        "postal_code": "160-0023",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "西新宿7-7-32",
        "latitude": 35.6895,
        "longitude": 139.6920,
        "layout": "1K",
        "floor_area_sqm": "22.80",
        "building_year": 2012,
        "structure": "RC",
        "floor_number": 3,
        "orientation": "E",
        "monthly_rent_jpy": "78000",
        "management_fee_jpy": "3000",
        "shikikin_months": "1.0",
        "reikin_months": "0.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shinjuku-001",
        "title": "新宿御苑前 2LDK ファミリー向け",
        "postal_code": "160-0014",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "内藤町2-7",
        "latitude": 35.6854,
        "longitude": 139.7143,
        "layout": "2LDK",
        "floor_area_sqm": "65.00",
        "building_year": 2020,
        "structure": "RC",
        "floor_number": 12,
        "orientation": "SE",
        "monthly_rent_jpy": "215000",
        "management_fee_jpy": "8000",
        "shikikin_months": "2.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shinjuku-001",
        "title": "高田馬場 1DK リノベ済み",
        "postal_code": "169-0075",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "高田馬場2-14-5",
        "latitude": 35.7122,
        "longitude": 139.7031,
        "layout": "1DK",
        "floor_area_sqm": "30.00",
        "building_year": 2008,
        "structure": "STEEL",
        "floor_number": 2,
        "orientation": "N",
        "monthly_rent_jpy": "92000",
        "management_fee_jpy": "4000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "0.5",
        "status": "available",
    },
    {
        "org_id": "org-shinjuku-001",
        "title": "四谷 1LDK 築浅 駅5分",
        "postal_code": "160-0004",
        "prefecture": "東京都",
        "city": "新宿区",
        "address_line1": "四谷1-1-8",
        "latitude": 35.6868,
        "longitude": 139.7301,
        "layout": "1LDK",
        "floor_area_sqm": "38.50",
        "building_year": 2022,
        "structure": "RC",
        "floor_number": 6,
        "orientation": "SW",
        "monthly_rent_jpy": "135000",
        "management_fee_jpy": "6000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    # ── Shibuya org ───────────────────────────────────────────────────────────
    {
        "org_id": "org-shibuya-002",
        "title": "渋谷 1K 渋谷駅徒歩3分",
        "postal_code": "150-0002",
        "prefecture": "東京都",
        "city": "渋谷区",
        "address_line1": "渋谷1-24-12",
        "latitude": 35.6598,
        "longitude": 139.7032,
        "layout": "1K",
        "floor_area_sqm": "25.00",
        "building_year": 2015,
        "structure": "RC",
        "floor_number": 5,
        "orientation": "S",
        "monthly_rent_jpy": "105000",
        "management_fee_jpy": "5000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shibuya-002",
        "title": "恵比寿 1LDK 閑静な住宅街",
        "postal_code": "150-0013",
        "prefecture": "東京都",
        "city": "渋谷区",
        "address_line1": "恵比寿2-1-5",
        "latitude": 35.6469,
        "longitude": 139.7101,
        "layout": "1LDK",
        "floor_area_sqm": "45.00",
        "building_year": 2019,
        "structure": "RC",
        "floor_number": 4,
        "orientation": "SE",
        "monthly_rent_jpy": "165000",
        "management_fee_jpy": "7000",
        "shikikin_months": "2.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shibuya-002",
        "title": "代官山 2LDK ハイグレード",
        "postal_code": "150-0034",
        "prefecture": "東京都",
        "city": "渋谷区",
        "address_line1": "代官山町17-6",
        "latitude": 35.6484,
        "longitude": 139.7029,
        "layout": "2LDK",
        "floor_area_sqm": "70.00",
        "building_year": 2021,
        "structure": "SRC",
        "floor_number": 10,
        "orientation": "S",
        "monthly_rent_jpy": "220000",
        "management_fee_jpy": "10000",
        "shikikin_months": "2.0",
        "reikin_months": "2.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-shibuya-002",
        "title": "幡ヶ谷 1DK 女性専用",
        "postal_code": "151-0072",
        "prefecture": "東京都",
        "city": "渋谷区",
        "address_line1": "幡ヶ谷1-4-8",
        "latitude": 35.6693,
        "longitude": 139.6857,
        "layout": "1DK",
        "floor_area_sqm": "28.00",
        "building_year": 2010,
        "structure": "STEEL",
        "floor_number": 2,
        "orientation": "E",
        "monthly_rent_jpy": "82000",
        "management_fee_jpy": "3000",
        "shikikin_months": "1.0",
        "reikin_months": "0.0",
        "koushinryo_months": "0.5",
        "status": "available",
    },
    {
        "org_id": "org-shibuya-002",
        "title": "神泉 1K ペット相談可",
        "postal_code": "150-0021",
        "prefecture": "東京都",
        "city": "渋谷区",
        "address_line1": "円山町22-7",
        "latitude": 35.6552,
        "longitude": 139.6965,
        "layout": "1K",
        "floor_area_sqm": "24.00",
        "building_year": 2016,
        "structure": "RC",
        "floor_number": 3,
        "orientation": "W",
        "monthly_rent_jpy": "88000",
        "management_fee_jpy": "4000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    # ── Setagaya org ──────────────────────────────────────────────────────────
    {
        "org_id": "org-setagaya-003",
        "title": "下北沢 1LDK 個性的な街",
        "postal_code": "155-0031",
        "prefecture": "東京都",
        "city": "世田谷区",
        "address_line1": "北沢2-6-14",
        "latitude": 35.6617,
        "longitude": 139.6671,
        "layout": "1LDK",
        "floor_area_sqm": "40.00",
        "building_year": 2017,
        "structure": "RC",
        "floor_number": 5,
        "orientation": "S",
        "monthly_rent_jpy": "125000",
        "management_fee_jpy": "5000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-setagaya-003",
        "title": "三軒茶屋 1K 商業立地",
        "postal_code": "154-0004",
        "prefecture": "東京都",
        "city": "世田谷区",
        "address_line1": "太子堂4-1-7",
        "latitude": 35.6449,
        "longitude": 139.6697,
        "layout": "1K",
        "floor_area_sqm": "21.50",
        "building_year": 2011,
        "structure": "WOOD",
        "floor_number": 1,
        "orientation": "N",
        "monthly_rent_jpy": "72000",
        "management_fee_jpy": "3000",
        "shikikin_months": "0.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-setagaya-003",
        "title": "用賀 2LDK ファミリー住宅",
        "postal_code": "158-0098",
        "prefecture": "東京都",
        "city": "世田谷区",
        "address_line1": "用賀3-4-11",
        "latitude": 35.6271,
        "longitude": 139.6489,
        "layout": "2LDK",
        "floor_area_sqm": "68.00",
        "building_year": 2014,
        "structure": "RC",
        "floor_number": 3,
        "orientation": "SE",
        "monthly_rent_jpy": "190000",
        "management_fee_jpy": "8000",
        "shikikin_months": "2.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
    {
        "org_id": "org-setagaya-003",
        "title": "経堂 1DK 自然豊か",
        "postal_code": "156-0051",
        "prefecture": "東京都",
        "city": "世田谷区",
        "address_line1": "宮坂1-9-3",
        "latitude": 35.6494,
        "longitude": 139.6491,
        "layout": "1DK",
        "floor_area_sqm": "29.50",
        "building_year": 2013,
        "structure": "STEEL",
        "floor_number": 2,
        "orientation": "NE",
        "monthly_rent_jpy": "87000",
        "management_fee_jpy": "4000",
        "shikikin_months": "1.0",
        "reikin_months": "0.0",
        "koushinryo_months": "0.5",
        "status": "available",
    },
    {
        "org_id": "org-setagaya-003",
        "title": "千歳船橋 1LDK 閑静 駅近",
        "postal_code": "157-0071",
        "prefecture": "東京都",
        "city": "世田谷区",
        "address_line1": "千歳台1-6-2",
        "latitude": 35.6356,
        "longitude": 139.6349,
        "layout": "1LDK",
        "floor_area_sqm": "43.00",
        "building_year": 2020,
        "structure": "RC",
        "floor_number": 7,
        "orientation": "S",
        "monthly_rent_jpy": "130000",
        "management_fee_jpy": "6000",
        "shikikin_months": "1.0",
        "reikin_months": "1.0",
        "koushinryo_months": "1.0",
        "status": "available",
    },
]

# ── Provider configs (sandbox) ─────────────────────────────────────────────────

PROVIDER_CONFIGS = [
    {
        "org_id": "org-shinjuku-001",
        "provider_type": "payment",
        "provider_name": "komoju",
        "is_sandbox": True,
        "config_encrypted": None,  # No real credentials in seed
    },
    {
        "org_id": "org-shinjuku-001",
        "provider_type": "esign",
        "provider_name": "cloudsign",
        "is_sandbox": True,
        "config_encrypted": None,
    },
    {
        "org_id": "org-shibuya-002",
        "provider_type": "payment",
        "provider_name": "komoju",
        "is_sandbox": True,
        "config_encrypted": None,
    },
    {
        "org_id": "org-shibuya-002",
        "provider_type": "esign",
        "provider_name": "cloudsign",
        "is_sandbox": True,
        "config_encrypted": None,
    },
    {
        "org_id": "org-setagaya-003",
        "provider_type": "payment",
        "provider_name": "komoju",
        "is_sandbox": True,
        "config_encrypted": None,
    },
    {
        "org_id": "org-setagaya-003",
        "provider_type": "esign",
        "provider_name": "cloudsign",
        "is_sandbox": True,
        "config_encrypted": None,
    },
]


def _preflight_schema_check(db: "Session") -> None:  # type: ignore[name-defined]
    """Verify every table this script writes to actually exists.

    The seed script was authored against an aspirational schema (`organizations`,
    `jp_listings`). As of migration 0159 the real schema uses `users` (host via
    `host_id`), `houses` (listing table), and keeps `org_id` as a soft VARCHAR
    tenant tag without a dedicated `organizations` table. Rather than silently
    corrupting data if the schema diverges, fail fast with a clear report so
    the operator can decide: either create the missing migrations first, or
    run a schema-aligned version of this script.
    """
    from sqlalchemy import text

    required = ["organizations", "jp_listings", "jp_rental_terms",
                "jp_property_info", "org_provider_configs"]
    missing: list[str] = []
    for table in required:
        exists = db.execute(
            text(
                "SELECT 1 FROM information_schema.tables "
                "WHERE table_name = :t LIMIT 1"
            ),
            {"t": table},
        ).fetchone()
        if not exists:
            missing.append(table)

    if missing:
        msg = (
            "[seed_jp_launch] ABORT — required tables missing:\n"
            + "\n".join(f"  - {t}" for t in missing)
            + "\n\nThis script was authored against tables that do not exist in\n"
            "the current migration state (last applied: 0159). Options:\n"
            "  1. Create missing tables via Alembic (new 0160+ migration) and\n"
            "     re-run. The expected columns are documented in this script.\n"
            "  2. Rewrite _seed_listings() to target `houses` (actual listing\n"
            "     table) and _seed_orgs() to insert broker users with role tag\n"
            "     instead of a dedicated organizations table.\n"
            "Refusing to proceed to avoid data corruption."
        )
        print(msg, file=sys.stderr)
        raise SystemExit(2)


def _seed_orgs(db: "Session") -> None:  # type: ignore[name-defined]
    """Insert broker orgs. Idempotent via org_id check."""
    from sqlalchemy import text

    print("[seed] Seeding broker orgs...")
    for org in BROKER_ORGS:
        existing = db.execute(
            text("SELECT id FROM organizations WHERE org_id = :org_id"),
            {"org_id": org["org_id"]},
        ).fetchone()
        if existing:
            print(f"  [skip] org {org['org_id']} already exists")
            continue
        db.execute(
            text(
                "INSERT INTO organizations "
                "(org_id, name, prefecture, city, email, phone, region, verified_at, created_at) "
                "VALUES (:org_id, :name, :prefecture, :city, :email, :phone, 'jp', :now, :now)"
            ),
            {**org, "now": datetime.now(timezone.utc)},
        )
        print(f"  [created] org {org['org_id']} — {org['name']}")
    db.commit()


def _seed_listings(db: "Session") -> None:  # type: ignore[name-defined]
    """Insert chintai listings + rental terms + property info. Idempotent via title+org."""
    from sqlalchemy import text

    print("[seed] Seeding JP listings...")
    for listing in LISTINGS:
        # Check idempotency: title + org_id combination
        existing = db.execute(
            text(
                "SELECT id FROM jp_listings "
                "WHERE org_id = :org_id AND title = :title AND region = 'jp'"
            ),
            {"org_id": listing["org_id"], "title": listing["title"]},
        ).fetchone()
        if existing:
            print(f"  [skip] listing '{listing['title']}' already exists")
            continue

        now = datetime.now(timezone.utc)

        # Insert listing
        listing_result = db.execute(
            text(
                "INSERT INTO jp_listings "
                "(org_id, title, status, postal_code, prefecture, city, "
                " address_line1, latitude, longitude, region, created_at, updated_at) "
                "VALUES "
                "(:org_id, :title, :status, :postal_code, :prefecture, :city, "
                " :address_line1, :latitude, :longitude, 'jp', :now, :now) "
                "RETURNING id"
            ),
            {
                "org_id": listing["org_id"],
                "title": listing["title"],
                "status": listing["status"],
                "postal_code": listing["postal_code"],
                "prefecture": listing["prefecture"],
                "city": listing["city"],
                "address_line1": listing["address_line1"],
                "latitude": listing["latitude"],
                "longitude": listing["longitude"],
                "now": now,
            },
        )
        listing_id = listing_result.fetchone()[0]

        # Insert rental terms
        db.execute(
            text(
                "INSERT INTO jp_rental_terms "
                "(org_id, region, monthly_rent_jpy, management_fee_jpy, "
                " shikikin_months, reikin_months, koushinryo_months, "
                " tax_treatment, created_at, updated_at) "
                "VALUES "
                "(:org_id, 'jp', :monthly_rent_jpy, :management_fee_jpy, "
                " :shikikin_months, :reikin_months, :koushinryo_months, "
                " 'included', :now, :now)"
            ),
            {
                "org_id": listing["org_id"],
                "monthly_rent_jpy": listing["monthly_rent_jpy"],
                "management_fee_jpy": listing["management_fee_jpy"],
                "shikikin_months": listing["shikikin_months"],
                "reikin_months": listing["reikin_months"],
                "koushinryo_months": listing["koushinryo_months"],
                "now": now,
            },
        )

        # Insert property info
        db.execute(
            text(
                "INSERT INTO jp_property_info "
                "(org_id, region, layout, floor_area_sqm, building_year, "
                " structure, floor_number, orientation, "
                " available_from, created_at, updated_at) "
                "VALUES "
                "(:org_id, 'jp', :layout, :floor_area_sqm, :building_year, "
                " :structure, :floor_number, :orientation, "
                " :available_from, :now, :now)"
            ),
            {
                "org_id": listing["org_id"],
                "layout": listing["layout"],
                "floor_area_sqm": listing["floor_area_sqm"],
                "building_year": listing["building_year"],
                "structure": listing["structure"],
                "floor_number": listing["floor_number"],
                "orientation": listing["orientation"],
                "available_from": date.today().isoformat(),
                "now": now,
            },
        )

        db.commit()
        print(f"  [created] listing_id={listing_id} '{listing['title']}'")


def _seed_provider_configs(db: "Session") -> None:  # type: ignore[name-defined]
    """Insert OrgProviderConfig (sandbox mode). Idempotent via unique constraint."""
    from sqlalchemy import text

    print("[seed] Seeding provider configs...")
    for cfg in PROVIDER_CONFIGS:
        existing = db.execute(
            text(
                "SELECT id FROM org_provider_configs "
                "WHERE org_id = :org_id "
                "  AND provider_type = :provider_type "
                "  AND provider_name = :provider_name"
            ),
            {
                "org_id": cfg["org_id"],
                "provider_type": cfg["provider_type"],
                "provider_name": cfg["provider_name"],
            },
        ).fetchone()
        if existing:
            print(
                f"  [skip] config {cfg['org_id']}/{cfg['provider_type']}/{cfg['provider_name']}"
            )
            continue

        now = datetime.now(timezone.utc)
        db.execute(
            text(
                "INSERT INTO org_provider_configs "
                "(org_id, provider_type, provider_name, is_sandbox, config_encrypted, "
                " created_at, updated_at) "
                "VALUES "
                "(:org_id, :provider_type, :provider_name, :is_sandbox, :config_encrypted, "
                " :now, :now)"
            ),
            {**cfg, "now": now},
        )
        print(
            f"  [created] config {cfg['org_id']}/{cfg['provider_type']}/{cfg['provider_name']}"
        )
    db.commit()


def main() -> None:
    args = _parse_args()
    _guard_env(args)

    # Late import to avoid SQLAlchemy mapper issues at module load
    from app.database import SessionLocal  # noqa: PLC0415

    print(f"\n[seed_jp_launch] Starting JP launch seed (env={args.env})...")
    with SessionLocal() as db:
        try:
            _preflight_schema_check(db)
            _seed_orgs(db)
            _seed_listings(db)
            _seed_provider_configs(db)
            print("\n[seed_jp_launch] Done. All data seeded successfully.")
        except Exception as exc:
            db.rollback()
            print(f"\n[seed_jp_launch] ERROR: {exc}", file=sys.stderr)
            raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
