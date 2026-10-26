"""Sale đang mang `role='guest'` → nâng lên `role='host'`.

Vì sao: trong mô hình nghiệp vụ, **sale CHÍNH LÀ người đăng tin**. Chủ nhà
(`account_type='owner'`) là vai khác — quản lý điện nước, hoá đơn — và đăng tin
phải thông qua môi giới. Seed đầu tiên (05/09/2026) cho sale `role='guest'` vì
tưởng sale là tài khoản thường, hậu quả là `PUT`/`DELETE /api/houses/{id}` (gác
bằng `require_host`) trả 403 ngay trên tin của chính họ.

Sửa ở DỮ LIỆU chứ không nới cổng: hai endpoint kia vẫn phải đòi host, vì chúng
là cửa sửa/xoá tin.

Chạy:
    docker exec -i <backend> python scripts/nang_sale_len_host.py
Idempotent — chạy lại không đổi gì thêm.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal  # noqa: E402
from app import models  # noqa: E402


def main() -> int:
    db = SessionLocal()
    try:
        ds = (
            db.query(models.User)
            .filter(
                models.User.account_type == "sale",
                models.User.role != "host",
            )
            .all()
        )
        if not ds:
            print("Không có tài khoản sale nào cần nâng.")
            return 0
        for u in ds:
            print(f"  {u.id:>4}  {u.email:<28} {u.role} → host")
            u.role = "host"
        db.commit()
        print(f"Đã nâng {len(ds)} tài khoản sale lên role='host'.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
