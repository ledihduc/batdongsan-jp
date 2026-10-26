"""Tìm kiếm HỢP NHẤT toàn hệ thống: tin đăng (nhà).

Public (khách chưa đăng nhập vẫn tìm được — browse-first).
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.database import get_db
from app import models
from app.helpers import (
    house_to_dict,
    nap_san_cho_tin,
)

router = APIRouter(prefix="/api/search", tags=["search"])

_PER_GROUP = 6


def _like(q: str) -> str:
    # Escape ký tự đặc biệt của LIKE để tránh người dùng gõ %/_ làm sai kết quả.
    safe = q.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{safe}%"


@router.get("")
def unified_search(
    q: str = Query("", max_length=100),
    db: Session = Depends(get_db),
):
    term = (q or "").strip()
    if len(term) < 2:
        return {"query": term, "houses": []}
    pat = _like(term)

    # 1) Tin đăng (nhà) — chỉ tin CÔNG KHAI. Status hiển thị công khai là
    # 'published' (list_houses lọc PUBLISHED); 'approved' là alias cũ → gộp cả 2
    # cho chắc. Khớp tiêu đề/địa chỉ/mô tả/thành phố/quận.
    houses = (
        db.query(models.House)
        .filter(
            models.House.status.in_(["published", "approved"]),
            or_(
                models.House.title.ilike(pat),
                models.House.address.ilike(pat),
                models.House.description.ilike(pat),
                models.House.city.ilike(pat),
                models.House.district.ilike(pat),
            ),
        )
        .order_by(models.House.created_at.desc())
        .limit(_PER_GROUP)
        .all()
    )

    tra_cuu = nap_san_cho_tin(db, houses)
    return {
        "query": term,
        "houses": [house_to_dict(db, h, tra_cuu) for h in houses],
    }
