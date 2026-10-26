#!/usr/bin/env python3
"""CI guard: ensure no migration alters host_id columns on the 20+ business tables.

AC-52: host_id is the structural immutable ownership column. ALTER on host_id
in any business table would break the entire cascade FK chain.

Usage (CI step):
    python scripts/check_no_host_id_alter.py
    echo $?   # 0 = clean, 1 = violation found

Also checks for:
  - op.drop_column on host_id
  - Raw SQL patterns: ALTER TABLE ... RENAME COLUMN host_id
  - op.alter_column with column_name='host_id'

Exit codes:
  0 — no violations found
  1 — one or more violations found (CI should block merge)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
BACKEND_ROOT = Path(__file__).parent.parent
VERSIONS_DIR = BACKEND_ROOT / "alembic" / "versions"

# ── Patterns to detect ────────────────────────────────────────────────────────
# Match Alembic Python API calls that touch host_id
_PYTHON_PATTERNS: list[re.Pattern] = [
    # op.alter_column("table", "host_id", ...) or op.alter_column(table, "host_id")
    re.compile(r'op\.alter_column\s*\([^)]*["\']host_id["\']', re.IGNORECASE),
    # op.drop_column("table", "host_id")
    re.compile(r'op\.drop_column\s*\([^)]*["\']host_id["\']', re.IGNORECASE),
    # batch_op.alter_column("host_id", ...)
    re.compile(r'batch_op\.alter_column\s*\(["\']host_id["\']', re.IGNORECASE),
    # batch_op.drop_column("host_id")
    re.compile(r'batch_op\.drop_column\s*\(["\']host_id["\']', re.IGNORECASE),
]

# Match raw SQL statements
_SQL_PATTERNS: list[re.Pattern] = [
    # ALTER TABLE ... RENAME COLUMN host_id TO ...
    re.compile(r'RENAME\s+COLUMN\s+host_id', re.IGNORECASE),
    # ALTER TABLE ... ALTER COLUMN host_id ...
    re.compile(r'ALTER\s+COLUMN\s+host_id', re.IGNORECASE),
    # DROP COLUMN host_id
    re.compile(r'DROP\s+COLUMN\s+host_id', re.IGNORECASE),
]

ALL_PATTERNS = _PYTHON_PATTERNS + _SQL_PATTERNS


def check_file(path: Path) -> list[tuple[int, str]]:
    """Return list of (line_number, matched_line) for violations in a file."""
    violations: list[tuple[int, str]] = []
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return []

    for line_no, line in enumerate(content.splitlines(), start=1):
        for pattern in ALL_PATTERNS:
            if pattern.search(line):
                violations.append((line_no, line.rstrip()))
                break  # Report each line once even if multiple patterns match

    return violations


def main() -> int:
    """Scan all migration files. Return 0 if clean, 1 if violations found."""
    if not VERSIONS_DIR.exists():
        print(f"ERROR: versions directory not found: {VERSIONS_DIR}", file=sys.stderr)
        return 1

    migration_files = sorted(VERSIONS_DIR.glob("*.py"))
    # Skip __init__.py and similar
    migration_files = [f for f in migration_files if f.name[0].isdigit()]

    all_violations: dict[str, list[tuple[int, str]]] = {}

    for mig_file in migration_files:
        violations = check_file(mig_file)
        if violations:
            all_violations[str(mig_file.relative_to(BACKEND_ROOT))] = violations

    if not all_violations:
        print(
            f"[AC-52 check] PASS — scanned {len(migration_files)} migration files. "
            "No host_id ALTER/DROP detected."
        )
        return 0

    print("[AC-52 check] FAIL — host_id modification detected in migration files!", file=sys.stderr)
    print(
        "AC-52 mandate: host_id is the structural ownership column and MUST NOT be altered.",
        file=sys.stderr,
    )
    print(file=sys.stderr)

    for filepath, violations in all_violations.items():
        print(f"  File: {filepath}", file=sys.stderr)
        for line_no, line in violations:
            print(f"    Line {line_no}: {line}", file=sys.stderr)
        print(file=sys.stderr)

    print(
        f"Total: {sum(len(v) for v in all_violations.values())} violation(s) in "
        f"{len(all_violations)} file(s).",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
