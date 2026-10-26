"""Chép chứng từ riêng tư đang nằm ở `/uploads` vào kho riêng + đăng ký vào
`private_documents` (để cổng `/uploads` chặn được khi bật PRIVATE_UPLOADS_ENFORCED).

Chạy:
    python scripts/migrate_private_uploads.py            # DRY-RUN (mặc định): chỉ đếm
    python scripts/migrate_private_uploads.py --apply    # chép + đăng ký

- Đọc các cột nhạy cảm theo danh mục `app/services/admin_v2/documents.SOURCES`
  (chỉ kiểu lưu `legacy` = giá trị dạng `/uploads/<tên>`). Kho nhạy cảm/CCCD
  vốn đã không mount tĩnh → bỏ qua.
- GIỮ bản gốc trong upload_dir: app cũ vẫn đọc bằng link `/uploads` cho tới khi
  bật cổng chặn. Idempotent: tên đã đăng ký thì bỏ qua; chạy lại bao nhiêu lần
  cũng được.
- Một tên được nhiều hàng dùng chung → chỉ đăng ký MỘT lần (legacy_upload_name unique).
"""

from __future__ import annotations

import argparse
import hashlib
import mimetypes
import os
import shutil
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app.domain  # noqa: E402,F401 — đăng ký bảng domain
from app import models  # noqa: E402
from app.config import settings  # noqa: E402
from app.services.admin_v2 import documents as docs  # noqa: E402

BATCH = 500


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _iter_rows(db, model):
    last = 0
    pk = model.id
    while True:
        rows = db.query(model).filter(pk > last).order_by(pk.asc()).limit(BATCH).all()
        if not rows:
            return
        yield from rows
        last = rows[-1].id


def run(db, *, apply: bool, out=print) -> dict:
    upload_dir = Path(settings.upload_dir).resolve()
    priv = docs.private_dir()
    registered = {r[0] for r in db.query(models.PrivateDocument.legacy_upload_name)
                  .filter(models.PrivateDocument.legacy_upload_name.isnot(None)).all()}
    seen: set[str] = set()
    stats: dict = defaultdict(lambda: defaultdict(int))
    for code, spec in docs.SOURCES.items():
        legacy_fields = {f: fs for f, fs in spec.fields.items() if fs.storage == "legacy"}
        if not legacy_fields:
            stats[code]["skipped_private_storage"] += 1
            continue
        model = _model_of(code)
        for row in _iter_rows(db, model):
            for fname, fs in legacy_fields.items():
                for raw in docs._values(row, fname, fs):
                    s = stats[code]
                    s["referenced"] += 1
                    name = docs.legacy_name(raw)
                    if name is None:
                        s["external_or_invalid"] += 1
                        continue
                    if name in registered:
                        s["already_registered"] += 1
                        continue
                    if name in seen:
                        s["shared_reference"] += 1
                        continue
                    src = upload_dir / name
                    if not src.is_file():
                        s["missing_file"] += 1
                        continue
                    seen.add(name)
                    s["to_register"] += 1
                    if not apply:
                        continue
                    key = f"legacy/{fs.category}/{name}"
                    dst = priv / key
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    if not dst.exists():
                        shutil.copy2(src, dst)
                    try:
                        os.chmod(dst, 0o600)
                    except OSError:
                        pass
                    db.add(models.PrivateDocument(
                        object_key=key,
                        owner_user_id=spec.owner(row),
                        category=fs.category,
                        source_type=code,
                        source_id=str(row.id),
                        content_type=mimetypes.guess_type(name)[0] or "application/octet-stream",
                        size_bytes=dst.stat().st_size,
                        sha256=_sha256(dst),
                        legacy_upload_name=name,
                    ))
                    s["registered"] += 1
        if apply:
            db.commit()
    result = {k: dict(v) for k, v in stats.items()}
    for code, s in result.items():
        out(f"{code:28s} " + " ".join(f"{k}={v}" for k, v in sorted(s.items())))
    total = sum(s.get("registered" if apply else "to_register", 0) for s in result.values())
    out(("ĐÃ đăng ký" if apply else "DRY-RUN — sẽ đăng ký") + f": {total} tệp → {priv}")
    return result


def _model_of(code: str):
    return {
        "rental_journey": models.RentalJourney,
        "rental_journey_payment": models.RentalJourneyPayment,
        "rental_journey_report": models.RentalJourneyReport,
        "sale_application": models.SaleApplication,
        "platform_payment": models.PlatformPayment,
        "contract": models.Contract,
        "contractor": models.Contractor,
    }[code]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--apply", action="store_true", help="Thật sự chép + ghi DB (mặc định chỉ đếm)")
    args = ap.parse_args()
    from app.database import SessionLocal

    db = SessionLocal()
    try:
        run(db, apply=args.apply)
    finally:
        db.close()


if __name__ == "__main__":
    main()
