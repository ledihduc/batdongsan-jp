"""
Luồng thẩm định chất lượng nhà trọ (Phase 2).

- POST /api/houses/{id}/verification   — chủ tin yêu cầu thẩm định.
- GET  /api/verification/queue         — admin/thẩm-định-viên xem hàng đợi.
- POST /api/verification/{id}/complete — admin gắn verified_star (kiểm tra xong).
- POST /api/verification/{id}/reject   — admin từ chối.

Phí (fee) DEFERRED chờ Payment core. Admin đóng vai thẩm định viên (slice 1;
vai trò 'verifier' riêng để Phase sau). Gate flag `verification_enabled`.
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import auth, models
from app.config import settings
from app.database import get_db
from app.services.admin_v2 import content_ops

router = APIRouter(prefix="/api", tags=["verification"])

_OPEN = ("requested", "inspecting")


def _guard():
    if not getattr(settings, "verification_enabled", True):
        raise HTTPException(status_code=404, detail="Tính năng chưa mở")


def _to_dict(v: "models.VerificationRequest", house: "models.House | None") -> dict:
    return {
        "id": v.id,
        "house_id": v.house_id,
        "house_title": house.title if house else None,
        "host_id": v.host_id,
        "status": v.status,
        "payment_status": v.payment_status,
        "verified_star": v.verified_star,
        "note": v.note,
        "created_at": v.created_at.isoformat() if v.created_at else None,
        "completed_at": v.completed_at.isoformat() if v.completed_at else None,
    }


@router.post("/houses/{house_id}/verification", status_code=201)
def request_verification(
    house_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_host),
):
    _guard()
    house = db.get(models.House, house_id)
    if house is None:
        raise HTTPException(404, "Không tìm thấy tin")
    if house.host_id != int(claims["sub"]):
        raise HTTPException(403, "Chỉ chủ tin được yêu cầu thẩm định")

    # Đã có yêu cầu đang mở → trả về, không tạo trùng.
    existing = (
        db.query(models.VerificationRequest)
        .filter(
            models.VerificationRequest.house_id == house_id,
            models.VerificationRequest.status.in_(_OPEN),
        )
        .first()
    )
    if existing is not None:
        return _to_dict(existing, house)

    req = models.VerificationRequest(
        house_id=house_id, host_id=house.host_id, status="requested"
    )
    db.add(req)
    db.commit()
    db.refresh(req)
    return _to_dict(req, house)


@router.get("/verification/queue")
def verification_queue(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    _guard()
    rows = (
        db.query(models.VerificationRequest)
        .filter(models.VerificationRequest.status.in_(_OPEN))
        .order_by(models.VerificationRequest.created_at.asc())
        .all()
    )
    return {
        "requests": [
            _to_dict(r, db.get(models.House, r.house_id)) for r in rows
        ]
    }


class CompleteBody(BaseModel):
    verified_star: int = Field(..., ge=1, le=5)
    note: str | None = Field(default=None, max_length=1000)
    criteria: dict | None = None


@router.post("/verification/{req_id}/complete")
def complete_verification(
    req_id: int,
    body: CompleteBody,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    _guard()
    req = db.get(models.VerificationRequest, req_id)
    if req is None:
        raise HTTPException(404, "Không tìm thấy yêu cầu")
    if req.status == "done":
        raise HTTPException(409, "Yêu cầu đã hoàn tất")

    house = db.get(models.House, req.house_id)
    if house is None:
        raise HTTPException(404, "Không tìm thấy tin")

    # Ghi sao lên yêu cầu + lên tin: dùng CHUNG với Admin V2.
    content_ops.complete_verification(
        req, house,
        verified_star=body.verified_star, note=body.note, criteria=body.criteria,
        actor_id=int(claims["sub"]),
    )
    db.commit()
    db.refresh(req)
    return _to_dict(req, house)


@router.post("/verification/{req_id}/reject")
def reject_verification(
    req_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    _guard()
    req = db.get(models.VerificationRequest, req_id)
    if req is None:
        raise HTTPException(404, "Không tìm thấy yêu cầu")
    content_ops.reject_verification(req, actor_id=int(claims["sub"]))
    db.commit()
    return _to_dict(req, db.get(models.House, req.house_id))
