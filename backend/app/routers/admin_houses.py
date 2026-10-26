"""Admin — duyệt/từ chối tin đăng (moderation) + đánh cờ "Uy tín".

Tách riêng khỏi houses.py: toàn bộ require_admin (không dùng ownership check của
update_house — admin không phải chủ tin). Duyệt/từ chối kèm thông báo host + audit.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.house_status import HouseStatus
from app.database import get_db
from app.services.admin_v2 import content_ops

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin/houses", tags=["admin-houses"])


@router.get("")
def admin_list_houses(
    status: str = HouseStatus.PENDING_REVIEW,
    limit: int = 0,
    offset: int = 0,
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
):
    """Liệt kê tin theo status cho admin (pending/approved/rejected/all)."""
    q = db.query(models.House)
    if status and status != "all":
        q = q.filter(models.House.status == status)
    total = q.count()
    q = q.order_by(models.House.created_at.desc())
    if limit > 0:
        q = q.limit(limit)
    if offset > 0:
        q = q.offset(offset)
    ds = q.all()
    tra_cuu = helpers.nap_san_cho_tin(db, ds)
    return {
        "houses": [helpers.house_to_dict(db, h, tra_cuu) for h in ds],
        "total": total,
    }


@router.post("/{house_id}/moderate")
def moderate_house(
    house_id: int,
    body: dict = Body(...),
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
):
    """Duyệt (approve) hoặc từ chối (reject) một tin. Reject bắt buộc có lý do."""
    action = (body.get("action") or "").lower()
    reason = (body.get("reason") or "").strip()

    if action not in ("approve", "reject"):
        raise HTTPException(
            422, detail={"code": "BAD_ACTION", "message": "action phải là approve|reject"}
        )
    if action == "reject" and not reason:
        raise HTTPException(
            422, detail={"code": "REASON_REQUIRED", "message": "Cần nhập lý do từ chối"}
        )

    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy tin")

    # Đổi trạng thái + thông báo chủ tin + audit dùng CHUNG với Admin V2.
    content_ops.moderate_listing(
        db, h, decision=action, reason=reason, actor_id=claims.get("sub")
    )

    db.commit()
    db.refresh(h)
    return {"house": helpers.house_to_dict(db, h)}


@router.patch("/{house_id}/trusted")
def toggle_trusted(
    house_id: int,
    body: dict = Body(...),
    claims: dict = Depends(auth.require_admin),
    db: Session = Depends(get_db),
):
    """Đánh / gỡ cờ "Uy tín" cho một tin đăng (admin only).

    Body: {"is_trusted": bool}
    - false→true: set trusted_at=now_utc(), trusted_by_admin_id=admin.id
    - true→false: clear trusted_at and trusted_by_admin_id
    Audit: AuditLog row (reuses audit_log_service.record) + structured logging.
    Returns: subset dict {id, is_trusted, trusted_at, trusted_by_admin_id}.
    """
    if "is_trusted" not in body:
        raise HTTPException(
            422, detail={"code": "MISSING_FIELD", "message": "Trường is_trusted là bắt buộc"}
        )

    new_trusted: bool = bool(body["is_trusted"])

    h = db.get(models.House, house_id)
    if not h:
        raise HTTPException(404, "Không tìm thấy tin")

    # Đổi cờ + structured log + AuditLog (best-effort) dùng CHUNG với Admin V2.
    content_ops.set_listing_trusted(db, h, is_trusted=new_trusted, actor_id=claims["sub"])

    db.commit()
    db.refresh(h)

    return {
        "id": h.id,
        "is_trusted": h.is_trusted,
        "trusted_at": h.trusted_at.isoformat() if h.trusted_at else None,
        "trusted_by_admin_id": h.trusted_by_admin_id,
    }
