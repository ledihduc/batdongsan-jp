"""audit_source_id_consistency.py — soi reservations + contracts.

Mục tiêu: phát hiện row mà chuỗi `source` không khớp với tên RevenueSource
mà `source_id` đang trỏ tới. Mismatch không phải bug schema (cả 2 cột
đều có giá trị) nhưng cho biết historical drift trước Phase 04 hoặc data
sửa tay.

Quy ước ánh xạ (giống source_service.resolve_default_source_id):
    direct       → "Trực tiếp"
    marketplace  → "Marketplace nội bộ"
    manual/other → "Khác"

Output:
    - reports/audit_source_id_<timestamp>.csv: 1 row per mismatch
    - stdout: tổng kết theo bảng + theo loại mismatch

Usage:
    DATABASE_URL=postgresql://... python scripts/audit_source_id_consistency.py
    DATABASE_URL=postgresql://... python scripts/audit_source_id_consistency.py --json
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from datetime import datetime
from pathlib import Path

# Đảm bảo import app.* khi script chạy standalone
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

_EXPECTED_NAME = {
    "direct": "Trực tiếp",
    "marketplace": "Marketplace nội bộ",
    "manual": "Khác",
}


def _expected(source_label: str | None) -> str:
    if source_label is None:
        return _EXPECTED_NAME["manual"]
    return _EXPECTED_NAME.get(source_label, _EXPECTED_NAME["manual"])


def _audit(table: str, conn) -> list[dict]:
    """Trả về list mismatch rows cho 1 bảng (reservations | contracts)."""
    from sqlalchemy import text

    rows = conn.execute(text(f"""
        SELECT
            t.id            AS row_id,
            t.host_id       AS host_id,
            t.source        AS source_text,
            t.source_id     AS source_id,
            rs.name         AS source_name
        FROM {table} t
        LEFT JOIN revenue_sources rs ON rs.id = t.source_id
        WHERE t.source_id IS NOT NULL
        ORDER BY t.id
    """)).mappings().all()

    mismatches: list[dict] = []
    for r in rows:
        expected = _expected(r["source_text"])
        actual = r["source_name"]
        if actual is None:
            # source_id trỏ vào revenue_source đã xoá → cũng coi là drift
            mismatches.append({
                "table": table,
                "row_id": r["row_id"],
                "host_id": r["host_id"],
                "source_text": r["source_text"],
                "source_id": r["source_id"],
                "source_name": None,
                "expected_name": expected,
                "issue": "dangling_source_id",
            })
        elif actual != expected:
            mismatches.append({
                "table": table,
                "row_id": r["row_id"],
                "host_id": r["host_id"],
                "source_text": r["source_text"],
                "source_id": r["source_id"],
                "source_name": actual,
                "expected_name": expected,
                "issue": "label_mismatch",
            })
    return mismatches


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true",
                        help="Output JSON to stdout thay vì CSV file.")
    parser.add_argument("--report-dir", default="reports",
                        help="Thư mục output CSV (default: reports/)")
    args = parser.parse_args()

    try:
        from app.database import engine
    except ImportError as e:
        print(f"[audit] Import error: {e}", file=sys.stderr)
        print("[audit] Set DATABASE_URL và cài requirements trước.",
              file=sys.stderr)
        return 1

    with engine.connect() as conn:
        mismatches = _audit("reservations", conn) + _audit("contracts", conn)

    # Stats
    by_table: dict[str, int] = {}
    by_issue: dict[str, int] = {}
    for m in mismatches:
        by_table[m["table"]] = by_table.get(m["table"], 0) + 1
        by_issue[m["issue"]] = by_issue.get(m["issue"], 0) + 1

    print(f"\n=== source_id audit @ {datetime.utcnow().isoformat()}Z ===")
    print(f"Total mismatches: {len(mismatches)}")
    print(f"By table:  {by_table}")
    print(f"By issue:  {by_issue}")

    if not mismatches:
        print("✓ No drift detected.")
        return 0

    if args.json:
        print(json.dumps(mismatches, indent=2, ensure_ascii=False))
        return 0

    out_dir = Path(args.report_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    out_file = out_dir / f"audit_source_id_{ts}.csv"
    with out_file.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "table", "row_id", "host_id",
            "source_text", "source_id",
            "source_name", "expected_name",
            "issue",
        ])
        writer.writeheader()
        writer.writerows(mismatches)

    print(f"→ Written {len(mismatches)} rows to {out_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
