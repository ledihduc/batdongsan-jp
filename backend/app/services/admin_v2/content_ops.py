"""Nghiệp vụ ĐỔI TRẠNG THÁI của cụm Nội dung — dùng chung cho route cũ và V2.

Mọi hàm ở đây KHÔNG commit: route cũ tự commit như trước, route V2 để
`run_command` commit một lần cùng nhật ký quản trị. Kiểm tra đầu vào (lý do,
chuyển trạng thái hợp lệ) để ở tầng route vì mỗi tầng trả lỗi theo kiểu riêng
(route cũ trả chuỗi, V2 trả `{code,message}`) — tách ra thì không đổi hành vi cũ.

Tác dụng phụ nghiệp vụ (thông báo chủ tin, dòng `audit_logs`, sao chất lượng
trên tin) nằm Ở ĐÂY để hai đường đi không lệch nhau.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Optional

from sqlalchemy.orm import Session

from app import helpers, models
from app.house_status import HouseStatus
from app.services import audit_log_service

logger = logging.getLogger(__name__)


class OpsError(Exception):
    """Lỗi nghiệp vụ trung tính: route cũ đổi thành HTTPException(detail=chuỗi),
    route V2 đổi thành `fail(status, code, message)`."""

    def __init__(self, status: int, code: str, message: str):
        super().__init__(message)
        self.status = status
        self.code = code
        self.message = message


def _audit(db: Session, *, host_id: int, action: str, extra: dict) -> None:
    # Nhật ký cũ là best-effort: hỏng ghi audit không được chặn thao tác chính.
    try:
        audit_log_service.record(db, host_id=host_id, action=action, success=True, extra=extra)
    except Exception as exc:  # noqa: BLE001
        logger.warning("audit %s failed: %s", action, exc)


# ── Tin đăng ──────────────────────────────────────────────────────────────────

LISTING_DECISIONS = ("approve", "reject", "unpublish")


def moderate_listing(
    db: Session, h: models.House, *, decision: str, reason: Optional[str], actor_id: Any
) -> dict:
    """approve | reject | unpublish. Trả {before, after} cho nhật ký.

    unpublish = gỡ tin ĐANG công khai → `hidden`, lý do ghi vào
    `rejection_reason` để chủ tin biết vì sao tin biến mất."""
    reason = (reason or "").strip()
    before = {"status": h.status, "rejection_reason": h.rejection_reason}
    if decision == "approve":
        h.status = HouseStatus.PUBLISHED
        h.rejection_reason = None
        helpers.push_notification(
            db, h.host_id, "house_approved",
            "Tin đăng đã được duyệt",
            f'Tin "{h.title}" đã được duyệt và hiển thị công khai.', h.id,
        )
    elif decision == "reject":
        h.status = HouseStatus.REJECTED
        h.rejection_reason = reason
        helpers.push_notification(
            db, h.host_id, "house_rejected",
            "Tin đăng bị từ chối",
            f'Tin "{h.title}" bị từ chối. Lý do: {reason}', h.id,
        )
    elif decision == "unpublish":
        h.status = HouseStatus.HIDDEN
        h.rejection_reason = reason
        helpers.push_notification(
            db, h.host_id, "house_hidden",
            "Tin đăng đã bị gỡ",
            f'Tin "{h.title}" đã bị gỡ khỏi trang công khai. Lý do: {reason}', h.id,
        )
    else:  # pragma: no cover — tầng route đã chặn
        raise OpsError(422, "BAD_ACTION", "Quyết định không hợp lệ")
    _audit(db, host_id=h.host_id, action=f"house_{decision}",
           extra={"house_id": h.id, "admin_id": actor_id, "reason": reason or None})
    return {"before": before, "after": {"status": h.status, "rejection_reason": h.rejection_reason}}


def published_conflict(db: Session, h: models.House) -> Optional[models.House]:
    """Tin khác của CÙNG phòng/kênh đang rao. Postgres có partial unique
    `uq_tin_dang_rao`; kiểm trước để trả 409 đọc được thay vì 500 lúc commit."""
    if not h.source_room_id:
        return None
    return (
        db.query(models.House)
        .filter(
            models.House.id != h.id,
            models.House.source_room_id == h.source_room_id,
            models.House.status == HouseStatus.PUBLISHED,
            models.House.transaction_type == h.transaction_type,
            models.House.product_type == h.product_type,
        )
        .first()
    )


def set_listing_trusted(db: Session, h: models.House, *, is_trusted: bool, actor_id: Any) -> dict:
    prev = bool(h.is_trusted)
    if is_trusted:
        h.is_trusted = True
        h.trusted_at = models.now_utc()
        h.trusted_by_admin_id = actor_id
    else:
        h.is_trusted = False
        h.trusted_at = None
        h.trusted_by_admin_id = None
    logger.info(
        "house_trusted_toggled house_id=%s admin_id=%s is_trusted=%s prev=%s",
        h.id, actor_id, is_trusted, prev,
    )
    _audit(db, host_id=h.host_id, action="house_trusted_toggled", extra={
        "house_id": h.id, "admin_id": actor_id, "is_trusted": is_trusted, "prev_is_trusted": prev,
    })
    return {"before": {"is_trusted": prev}, "after": {"is_trusted": bool(h.is_trusted)}}


# ── Báo cáo nội dung ──────────────────────────────────────────────────────────


def load_report_target(db: Session, target_type: str, target_id: int):
    if target_type == "house":
        return db.get(models.House, target_id)
    return None


def hide_report_target(db: Session, rep: models.ContentReport, *, reason: str, actor_id: Any) -> dict:
    """Ẩn nội dung bị báo cáo. Trả {target_type, target_id, before, after}.

    - house → như gỡ tin (hidden + thông báo chủ tin + audit).
    """
    obj = load_report_target(db, rep.target_type, rep.target_id)
    if obj is None:
        raise OpsError(404, "ADMIN_NOT_FOUND", "Nội dung bị báo cáo không còn tồn tại")
    before = getattr(obj, "status", None)
    if rep.target_type == "house":
        if obj.status in (HouseStatus.HIDDEN, "deleted"):
            return {"before": before, "after": obj.status, "changed": False}
        moderate_listing(db, obj, decision="unpublish", reason=reason, actor_id=actor_id)
    return {"before": before, "after": getattr(obj, "status", None), "changed": True}


def close_report(rep: models.ContentReport, *, status: str, actor_id: int) -> None:
    rep.status = status
    rep.reviewed_by = actor_id
    rep.reviewed_at = datetime.utcnow()


# ── Thẩm định sao ─────────────────────────────────────────────────────────────

VERIFICATION_OPEN = ("requested", "inspecting")


def complete_verification(
    req: models.VerificationRequest,
    house: models.House,
    *,
    verified_star: int,
    note: Optional[str],
    criteria: Optional[dict],
    actor_id: int,
) -> None:
    """Chốt thẩm định: ghi sao lên YÊU CẦU và lên TIN (cột từ mig 0042)."""
    now = datetime.utcnow()
    req.status = "done"
    req.verified_star = verified_star
    req.criteria_json = criteria
    req.note = note
    req.assignee_id = actor_id
    req.completed_at = now
    house.quality_verified_star = verified_star
    house.quality_verified_at = now
    if criteria:
        house.quality_criteria = criteria


def reject_verification(req: models.VerificationRequest, *, actor_id: int, note: Optional[str] = None) -> None:
    req.status = "rejected"
    req.assignee_id = actor_id
    req.completed_at = datetime.utcnow()
    if note is not None:
        req.note = note
