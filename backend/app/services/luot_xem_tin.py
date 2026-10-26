"""Đếm lượt xem tin theo ngày (bảng `house_view_days`, migration 0135).

Một câu upsert cho mỗi lượt mở trang chi tiết: không đọc trước rồi ghi, nên
hai người mở cùng lúc không làm mất lượt nào.
"""

from __future__ import annotations

from datetime import date
from typing import Optional

from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.orm import Session

from app import models
from app.services.short_stay_service import local_now


def ghi_luot_xem(db: Session, house_id: int, ngay: Optional[date] = None) -> None:
    """Cộng 1 lượt xem cho tin vào ngày (giờ VN). Không commit — để người gọi
    commit cùng `houses.view_count`."""
    # Cùng một câu ON CONFLICT cho Postgres (thật) và SQLite (test).
    insert = sqlite.insert if db.get_bind().dialect.name == "sqlite" else postgresql.insert
    cau = insert(models.HouseViewDay).values(
        house_id=house_id, ngay=ngay or local_now().date(), so_luot=1
    )
    db.execute(
        cau.on_conflict_do_update(
            index_elements=["house_id", "ngay"],
            set_={"so_luot": models.HouseViewDay.so_luot + 1},
        )
    )
