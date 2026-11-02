"""Danh mục dùng chung cho app: loại hình BĐS + tiện ích.

Router `catalog` gốc bị gỡ cùng cụm VN ở JP fork (Phase-03 VN-strip), nhưng app
vẫn gọi 2 route này lúc mở feed (`house_provider.fetchInitialData`) và ở form
đăng tin / nhu cầu → thiếu thì feed lỗi "Failed to fetch". Chỉ khôi phục phần
không gắn thị trường VN; `master/provinces|wards`, `geo/reverse` KHÔNG trả lại.

Endpoints:
    GET /api/categories  — loại hình đang dùng (`is_active`), theo `sort_order`
    GET /api/amenities   — mọi tiện ích, theo id
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import models
from app.config import settings
from app.database import get_db
from app.services.market_scope import market_scope_on, scope_categories

router = APIRouter(prefix="/api", tags=["catalog"])


@router.get("/categories")
def categories(db: Session = Depends(get_db)):
    # Loại đã bỏ (is_active=False) chỉ còn để tra tên dữ liệu cũ → không cho chọn.
    q = db.query(models.Category).filter(models.Category.is_active.is_(True))
    if market_scope_on():  # demo: chỉ loại hình của thị trường đang chạy (T14)
        q = scope_categories(q, settings.region)
    rows = q.order_by(models.Category.sort_order, models.Category.id).all()
    return {
        "categories": [
            {
                "id": c.id,
                "name": c.name,
                "icon": c.icon,
                "group_key": c.group_key,
                "sort_order": c.sort_order,
            }
            for c in rows
        ]
    }


@router.get("/amenities")
def amenities(db: Session = Depends(get_db)):
    rows = db.query(models.Amenity).order_by(models.Amenity.id).all()
    return {"amenities": [{"id": a.id, "name": a.name, "icon": a.icon} for a in rows]}
