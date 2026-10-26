"""
Sao chất lượng nhà trọ — chủ tự khai 5 tiêu chí → suy sao + gợi ý đơn giá.

GET  /api/houses/{house_id}/quality  — công khai (người thuê xem).
PUT  /api/houses/{house_id}/quality  — chủ sở hữu tin cập nhật tiêu chí.

Additive, gate flag `quality_rating_enabled`. Không dùng future annotations để
pydantic resolve model chuẩn.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import auth, models
from app.config import settings
from app.database import get_db
from app.services import quality_rating as qr

router = APIRouter(prefix="/api/houses", tags=["quality"])


class QualityCriteria(BaseModel):
    pccc: bool = False
    full_furniture: bool = False
    kitchen: bool = False
    private_bathroom: bool = False
    air_conditioner: bool = False


def _payload(house: models.House) -> dict:
    criteria = qr.normalize_criteria(house.quality_criteria)
    base_rate = getattr(settings, "quality_base_rate_per_m2", 150000)
    star = house.quality_verified_star or house.quality_self_star
    return {
        "house_id": house.id,
        "criteria": criteria,
        "self_star": house.quality_self_star,
        "verified_star": house.quality_verified_star,
        "is_verified": house.quality_verified_star is not None,
        "suggested_price": (
            qr.suggested_price(house.area or 0, star, base_rate) if star else None
        ),
    }


@router.get("/{house_id}/quality")
def get_quality(house_id: int, db: Session = Depends(get_db)):
    if not getattr(settings, "quality_rating_enabled", True):
        raise HTTPException(status_code=404, detail="Tính năng chưa mở")
    house = db.get(models.House, house_id)
    if house is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tin")
    return _payload(house)


@router.put("/{house_id}/quality")
def set_quality(
    house_id: int,
    body: QualityCriteria,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    if not getattr(settings, "quality_rating_enabled", True):
        raise HTTPException(status_code=404, detail="Tính năng chưa mở")
    house = db.get(models.House, house_id)
    if house is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tin")
    if house.host_id != int(claims["sub"]):
        raise HTTPException(status_code=403, detail="Chỉ chủ tin được cập nhật")

    criteria = qr.normalize_criteria(body.model_dump())
    house.quality_criteria = criteria
    house.quality_self_star = qr.compute_self_star(criteria)
    db.commit()
    db.refresh(house)
    return _payload(house)
