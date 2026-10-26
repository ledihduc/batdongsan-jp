"""Nghiệp vụ yêu cầu dịch vụ — router chỉ gọi xuống đây.

Ba quyết định đáng ghi lại:

1. **Chống gửi trùng 5 phút.** Bấm hai lần hoặc mạng chập chờn gửi lại sẽ tạo
   hai yêu cầu y hệt, và admin gọi khách hai lần — đủ để khách nghĩ mình đang
   bị làm phiền.

2. **Báo tin qua Telegram, không chỉ trong app.** Yêu cầu dịch vụ chỉ có giá
   trị nếu gọi lại trong vài phút. Thông báo in-app nằm im tới khi admin mở
   app — mà admin ở đây là một người, không ngồi trong app cả ngày.

3. **Mọi kênh báo tin đều nuốt lỗi.** Khách đã bấm gửi xong; không có lý do gì
   để họ nhận lỗi 500 vì Telegram trục trặc.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import helpers, models
from app.domain.service_request import Service, ServiceRequest
from app.schemas.service import ServiceRequestCreate
from app.services.notification import telegram_service

logger = logging.getLogger(__name__)

CUA_SO_CHONG_TRUNG_PHUT = 5


def danh_muc(db: Session) -> list[Service]:
    return (
        db.query(Service)
        .filter(Service.is_active == True)  # noqa: E712
        .order_by(Service.sort_order.asc(), Service.id.asc())
        .all()
    )


def tao_yeu_cau(
    db: Session, body: ServiceRequestCreate, *, user_id: int | None
) -> ServiceRequest:
    phone = body.phone.strip()

    moc = datetime.utcnow() - timedelta(minutes=CUA_SO_CHONG_TRUNG_PHUT)
    trung = (
        db.query(ServiceRequest)
        .filter(
            ServiceRequest.phone == phone,
            ServiceRequest.service_slug == body.service_slug,
            ServiceRequest.created_at >= moc,
        )
        .first()
    )
    if trung is not None:
        return trung

    dich_vu = (
        db.query(Service).filter(Service.slug == body.service_slug).first()
    )
    if dich_vu is None:
        raise HTTPException(status_code=404, detail="Dịch vụ không tồn tại")

    item = ServiceRequest(
        user_id=user_id,
        service_slug=body.service_slug,
        name=body.name.strip()[:200],
        phone=phone,
        area=body.area,
        budget=body.budget,
        description=body.description,
        images=body.images[:10] or None,
        province_code=body.province_code,
        location_text=(body.location_text or "").strip()[:200] or None,
        lat=body.lat,
        lng=body.lng,
        status="new",
        source="app" if user_id else "web",
    )
    db.add(item)
    db.commit()
    db.refresh(item)

    bao_admin(db, item, dich_vu.name)
    return item


def bao_admin(db: Session, item: ServiceRequest, ten_dich_vu: str) -> None:
    """Telegram (tới điện thoại thật) + thông báo trong app cho mọi admin."""
    try:
        telegram_service.gui_admin(
            "\n".join(
                [
                    f"🔔 Yêu cầu dịch vụ mới #{item.id}",
                    f"Dịch vụ: {ten_dich_vu}",
                    f"Khách: {item.name} — {item.phone}",
                    f"Khu vực: {item.location_text or item.area or '—'}",
                    f"Mô tả: {(item.description or '—')[:500]}",
                ]
            )
        )
    except Exception:  # noqa: BLE001 — đường báo tin không được phép chết
        logger.warning("telegram lỗi khi báo yêu cầu dịch vụ")

    try:
        admins = (
            db.query(models.User)
            .filter(
                models.User.role == "admin",
                models.User.is_active == True,  # noqa: E712
            )
            .all()
        )
        for a in admins:
            helpers.push_notification(
                db,
                a.id,
                "service_request",
                f"Yêu cầu dịch vụ mới: {ten_dich_vu}",
                f"{item.name} — {item.location_text or item.area or ''}".strip(" —"),
                related_id=item.id,
            )
        db.commit()
    except Exception:  # noqa: BLE001
        db.rollback()


def danh_sach_admin(
    db: Session,
    *,
    status: str | None = None,
    service_slug: str | None = None,
    q: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[ServiceRequest]:
    rows = db.query(ServiceRequest)
    if status:
        rows = rows.filter(ServiceRequest.status == status)
    if service_slug:
        rows = rows.filter(ServiceRequest.service_slug == service_slug)
    if q:
        kw = f"%{q.strip()}%"
        rows = rows.filter(
            (ServiceRequest.phone.ilike(kw)) | (ServiceRequest.name.ilike(kw))
        )
    return (
        rows.order_by(ServiceRequest.created_at.desc())
        .limit(max(1, min(limit, 200)))
        .offset(max(0, offset))
        .all()
    )


def danh_sach_cua_toi(
    db: Session, *, user_id: int, limit: int = 50
) -> list[ServiceRequest]:
    """Yêu cầu do CHÍNH user này gửi, mới nhất trước.

    Chỉ lọc theo `user_id`, KHÔNG theo số điện thoại: một số có thể do nhiều
    người dùng chung (nhà trọ, gia đình), lọc theo phone sẽ phơi yêu cầu của
    người khác — trong đó có địa chỉ nhà và mô tả tình trạng.
    """
    return (
        db.query(ServiceRequest)
        .filter(ServiceRequest.user_id == user_id)
        .order_by(ServiceRequest.created_at.desc())
        .limit(max(1, min(limit, 100)))
        .all()
    )


def thanh_dict_cua_toi(item: ServiceRequest, ten_dich_vu: dict[str, str]) -> dict:
    """Bản dành cho CHÍNH chủ.

    Bỏ `admin_note` (ghi chú vận hành nội bộ, có thể là "khách khó tính") và
    `source`. Giữ `phone` vì đây là số họ tự điền, cần thấy để biết mình có gõ
    nhầm không.
    """
    return {
        "id": item.id,
        "service_slug": item.service_slug,
        "service_name": ten_dich_vu.get(item.service_slug, item.service_slug),
        "name": item.name,
        "phone": item.phone,
        "area": item.area,
        "budget": item.budget,
        "description": item.description,
        "location_text": item.location_text,
        "status": item.status,
        "scheduled_at": item.scheduled_at,
        "contacted_at": item.contacted_at,
        "created_at": item.created_at,
    }


def thanh_dict_admin(item: ServiceRequest, ten_dich_vu: dict[str, str]) -> dict:
    return {
        "id": item.id,
        "service_slug": item.service_slug,
        "service_name": ten_dich_vu.get(item.service_slug, item.service_slug),
        "name": item.name,
        "phone": item.phone,
        "area": item.area,
        "budget": item.budget,
        "description": item.description,
        "province_code": item.province_code,
        "location_text": item.location_text,
        "status": item.status,
        "scheduled_at": item.scheduled_at,
        "contacted_at": item.contacted_at,
        "admin_note": item.admin_note,
        "source": item.source,
        "created_at": item.created_at,
    }
