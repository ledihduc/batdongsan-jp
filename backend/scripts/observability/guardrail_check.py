#!/usr/bin/env python3
"""
guardrail_check.py — CHỐT AN TOÀN CỨNG của pipeline self-heal.

Nhận danh sách file bị đổi (git diff) do Claude sinh ra và QUYẾT ĐỊNH:
  - exit 0  → SAFE: được phép verify + auto-deploy.
  - exit 2  → ESCALATE: chạm module nhạy cảm / file cấm → CHỜ người duyệt,
              KHÔNG auto-deploy.
  - exit 3  → NO-OP: không có file nào đổi.

Đây là lớp bảo vệ THẬT (không tin lời Claude): dù prompt có dặn gì, mọi diff
vẫn phải qua đây. Tôn trọng nguyên tắc "không đụng dữ liệu thật":
  - Cấm mọi thay đổi migration/schema/DB.
  - Cấm chạm module nhạy cảm (auth, kyc, bank, payment, delegation, retention…).
  - Cấm sửa file hạ tầng (.env, Dockerfile, requirements, CI, chính pipeline này).
  - Chỉ cho auto khi diff nằm trong vùng code ứng dụng an toàn.
"""

from __future__ import annotations

import argparse
import re
import sys

# ── File/đường dẫn CẤM → luôn escalate (không bao giờ auto-deploy) ────────────
SENSITIVE_PATTERNS = [
    r"(^|/)alembic/",             # migrations
    r"migration",
    r"(^|/)app/models\.py$",      # schema ORM
    r"(^|/)app/planning_models\.py$",
    r"(^|/)app/database\.py$",
    r"(^|/)app/config\.py$",      # chứa secret/settings
    r"(^|/)app/auth\.py$",
    r"kyc", r"bank", r"payment", r"invoice", r"contract",
    r"delegation", r"retention", r"owner_death", r"death",
    r"approval", r"dispute", r"fraud", r"sensitive", r"reveal",
    r"seed", r"backfill", r"restore", r"backup",
    r"\.env", r"Dockerfile", r"docker-compose", r"requirements\.txt",
    r"(^|/)\.github/",
    r"(^|/)scripts/observability/",  # pipeline không được tự sửa mình
]

# ── Vùng code được phép auto (whitelist) ─────────────────────────────────────
# Diff phải NẰM TRỌN trong các prefix này thì mới xét auto.
ALLOWED_PREFIXES = [
    "app/routers/",
    "app/services/",
    "app/repositories/",
    "app/domain/",
    "app/api/",
    "app/utils/",
    "app/helpers.py",
    "app/schemas/",
    "main.py",
    "tests/",
]

_sensitive_re = re.compile("|".join(SENSITIVE_PATTERNS), re.IGNORECASE)


def _in_allowed(path: str) -> bool:
    return any(
        path == p or path.startswith(p) for p in ALLOWED_PREFIXES
    )


def classify(files: list[str]) -> tuple[int, list[str]]:
    files = [f.strip() for f in files if f.strip()]
    if not files:
        return 3, ["no files changed"]

    reasons: list[str] = []
    verdict = 0
    for f in files:
        if _sensitive_re.search(f):
            reasons.append(f"SENSITIVE: {f}")
            verdict = 2
        elif not _in_allowed(f):
            reasons.append(f"OUT-OF-SCOPE: {f}")
            verdict = 2
        else:
            reasons.append(f"ok: {f}")
    return verdict, reasons


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--files", help="File chứa danh sách path (1 dòng/path). Mặc định đọc stdin.")
    args = ap.parse_args()

    if args.files:
        with open(args.files, encoding="utf-8") as fh:
            files = fh.read().splitlines()
    else:
        files = sys.stdin.read().splitlines()

    verdict, reasons = classify(files)
    label = {0: "SAFE", 2: "ESCALATE", 3: "NO-OP"}[verdict]
    print(f"VERDICT: {label}")
    for r in reasons:
        print(f"  {r}")
    return verdict


if __name__ == "__main__":
    sys.exit(main())
