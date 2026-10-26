"""Nghiệp vụ ĐỔI TRẠNG THÁI của cụm Đối tác + cấu hình — dùng chung route cũ và V2.

Không commit (route cũ tự commit; V2 để `run_command` commit cùng nhật ký).
Lỗi nghiệp vụ ném `OpsError` để mỗi tầng tự đổi sang kiểu lỗi của mình — route
cũ giữ nguyên chuỗi `detail` mà app Flutter đang hiển thị.
"""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Optional

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app import models
from app.services.admin_v2.content_ops import OpsError

__all__ = ["OpsError"]


def _now() -> datetime:
    return datetime.utcnow()


# ── Hồ sơ Sale ────────────────────────────────────────────────────────────────

SALE_CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
ACTIVE_APPLICATION_STATUSES = ("SUBMITTED", "IN_REVIEW", "REQUEST_CHANGES")


def sale_code(db: Session) -> str:
    for _ in range(20):
        code = "SL-" + "".join(secrets.choice(SALE_CODE_ALPHABET) for _ in range(6))
        found = db.query(models.SaleProfile.id).filter(models.SaleProfile.sale_code == code).first()
        if found is None:
            return code
    raise HTTPException(503, detail="Chưa thể cấp mã Sale, vui lòng thử lại")


def ensure_sale_profile(
    db: Session, *, user: models.User, application: models.SaleApplication
) -> models.SaleProfile:
    profile = db.query(models.SaleProfile).filter(models.SaleProfile.user_id == user.id).first()
    if profile is not None:
        return profile
    profile = models.SaleProfile(
        user_id=user.id,
        sale_code=sale_code(db),
        display_name=application.full_name,
        bio=application.bio,
        service_areas=application.service_areas or [],
        verified=True,
    )
    db.add(profile)
    db.flush()
    return profile


def review_sale_application(
    db: Session,
    item: models.SaleApplication,
    *,
    admin_id: int,
    decision: str,
    reason_code: Optional[str],
    review_note: Optional[str],
) -> None:
    """APPROVE | REJECT | REQUEST_CHANGES. Duyệt = cấp quyền Sale (account_type
    + SaleProfile). Kiểm trạng thái ở đây vì đó là luật nghiệp vụ, không phải
    kiểu dữ liệu đầu vào."""
    if item.status not in ACTIVE_APPLICATION_STATUSES:
        raise OpsError(409, "SALE_APPLICATION_INVALID_TRANSITION", "SALE_APPLICATION_INVALID_TRANSITION")
    item.reviewed_by = admin_id
    item.reviewed_at = _now()
    item.review_note = (review_note or "").strip() or None
    item.rejection_code = (reason_code or "").strip() or None
    if decision == "APPROVE":
        applicant = db.get(models.User, item.applicant_user_id)
        if applicant is None or not applicant.is_active:
            raise OpsError(409, "SALE_APPLICANT_INACTIVE", "Tài khoản ứng viên không còn hoạt động")
        if (applicant.account_type or "customer") == "owner":
            raise OpsError(409, "SALE_MULTI_ROLE_CLOSED", "Multi-role Sale và Chủ nhà chưa được mở")
        applicant.account_type = "sale"
        profile = ensure_sale_profile(db, user=applicant, application=item)
        item.approved_sale_profile_id = profile.id
        item.status = "APPROVED"
    elif decision == "REJECT":
        item.status = "REJECTED"
    else:
        item.status = "REQUEST_CHANGES"
    item.version += 1


def start_sale_application_review(item: models.SaleApplication, *, admin_id: int) -> None:
    """SUBMITTED → IN_REVIEW: đánh dấu có người đang xem để hai người không cùng duyệt."""
    if item.status != "SUBMITTED":
        raise OpsError(409, "SALE_APPLICATION_INVALID_TRANSITION", "Chỉ hồ sơ mới nộp mới chuyển sang đang xem xét")
    item.status = "IN_REVIEW"
    item.reviewed_by = admin_id
    item.version += 1


def add_activity_audit(
    db: Session, *, actor_user_id: int, action: str, idempotency_key: str,
    target_type: str, target_id: int, payload: Optional[dict] = None,
) -> None:
    db.add(models.ActivityAuditEvent(
        actor_user_id=actor_user_id, action=action, idempotency_key=idempotency_key[:128],
        target_type=target_type, target_id=target_id, payload=payload,
    ))


# ── Chính sách cọc ────────────────────────────────────────────────────────────

DEFAULT_SHORT_STAY_DEPOSIT_BPS = 1000
DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS = 5000


def percent_to_bps(value: Decimal) -> int:
    return int((value * Decimal("100")).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def percent_text(bps: int) -> str:
    return format((Decimal(bps) / Decimal("100")).normalize(), "f")


def policy_payload(item: Optional[models.ActivityPolicyVersion]) -> dict:
    if item is None:
        return {
            "policy_version": 0,
            "short_stay_primary_deposit_percent": percent_text(DEFAULT_SHORT_STAY_DEPOSIT_BPS),
            "long_term_platform_deposit_percent": percent_text(DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS),
            "long_term_owner_deposit_percent": percent_text(10000 - DEFAULT_LONG_TERM_PLATFORM_DEPOSIT_BPS),
            "effective_at": None,
            "provenance": "default",
        }
    return {
        "id": item.id,
        "policy_version": item.policy_version,
        "short_stay_primary_deposit_percent": percent_text(item.short_stay_primary_deposit_bps),
        "long_term_platform_deposit_percent": percent_text(item.long_term_platform_deposit_bps),
        "long_term_owner_deposit_percent": percent_text(10000 - item.long_term_platform_deposit_bps),
        "effective_at": item.effective_at.isoformat(),
        "reason": item.reason,
        "provenance": "admin_policy_version",
    }


def active_policy(db: Session, at: Optional[datetime] = None) -> Optional[models.ActivityPolicyVersion]:
    point = at or _now()
    return (
        db.query(models.ActivityPolicyVersion)
        .filter(models.ActivityPolicyVersion.effective_at <= point)
        .order_by(
            models.ActivityPolicyVersion.effective_at.desc(),
            models.ActivityPolicyVersion.policy_version.desc(),
        )
        .first()
    )


def latest_policy_version(db: Session) -> int:
    return int(db.query(func.max(models.ActivityPolicyVersion.policy_version)).scalar() or 0)


def create_deposit_policy_version(
    db: Session,
    *,
    admin_id: int,
    short_stay_percent: Decimal,
    long_term_platform_percent: Decimal,
    effective_at: Optional[datetime],
    reason: str,
) -> models.ActivityPolicyVersion:
    """Thêm MỘT phiên bản chính sách (không sửa bản cũ: giao dịch cũ giữ snapshot)."""
    effective_at = effective_at or _now()
    if effective_at.replace(tzinfo=None) < _now() - timedelta(minutes=1):
        raise OpsError(400, "ACTIVITY_POLICY_EFFECTIVE_TIME_INVALID", "ACTIVITY_POLICY_EFFECTIVE_TIME_INVALID")
    item = models.ActivityPolicyVersion(
        policy_version=latest_policy_version(db) + 1,
        short_stay_primary_deposit_bps=percent_to_bps(short_stay_percent),
        long_term_platform_deposit_bps=percent_to_bps(long_term_platform_percent),
        effective_at=effective_at.replace(tzinfo=None),
        reason=reason.strip(),
        created_by=admin_id,
    )
    db.add(item)
    db.flush()
    return item


# ── Lead / yêu cầu dịch vụ ────────────────────────────────────────────────────

CONTACTED_STATES = ("contacted", "scheduled", "done")


def touch_contacted(item, status: Optional[str]) -> None:
    # Mốc liên hệ đầu tiên ghi TỰ ĐỘNG và chỉ MỘT LẦN — số đo "gọi lại nhanh
    # hay chậm" (khách gửi 22h, 9h hôm sau mới gọi là mất khách).
    if status in CONTACTED_STATES and getattr(item, "contacted_at", None) is None:
        item.contacted_at = _now()


def update_service_request(
    item, *, status: Optional[str], scheduled_at: Optional[datetime], admin_note: Optional[str]
) -> None:
    """Cùng ngữ nghĩa `PATCH /api/services/requests/{id}` (status đã được kiểm)."""
    if status is not None:
        item.status = status
        touch_contacted(item, status)
    if scheduled_at is not None:
        item.scheduled_at = scheduled_at.replace(tzinfo=None)
    if admin_note is not None:
        item.admin_note = admin_note.strip() or None


