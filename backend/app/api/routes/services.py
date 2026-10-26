"""Cụm DỊCH VỤ — danh mục nghề + yêu cầu của khách.

  GET    /api/services                  — danh mục (công khai)
  POST   /api/services/requests         — khách gửi yêu cầu (không cần đăng nhập)
  GET    /api/services/requests/mine    — khách xem yêu cầu của CHÍNH mình
  GET    /api/services/requests         — admin xem danh sách (kèm SĐT)
  PATCH  /api/services/requests/{id}    — admin đổi trạng thái / xếp lịch / ghi chú

Router MỎNG: nghiệp vụ nằm ở `app/services/service_request/`.

THỨ TỰ KHAI BÁO: `/requests` đứng trước mọi route có tham số đường dẫn.

KHÔNG dùng `from __future__ import annotations` — chú thích kiểu thành chuỗi
thì pydantic không giải được thân request (lỗi đã ghi ở `routers/leads.py`).
"""

import re

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app import auth
from app.database import get_db
from app.domain.service_request import Service, ServiceRequest
from app.middleware.rate_limit import limiter
from app.schemas.service import (
    ServiceItem,
    ServiceRequestCreate,
    ServiceRequestPublic,
    ServiceRequestUpdate,
)
from app.services import service_request as nghiep_vu
from app.services.admin_v2 import partners_ops

router = APIRouter(prefix="/api/services", tags=["services"])

# Cùng khuôn với các form khác trong hệ: chấp nhận 0… / +84…
_PHONE_RE = re.compile(r"^(?:\+?84|0)(?:\d[\s.\-]?){8,10}$")


@router.get("", response_model=list[ServiceItem])
def list_services(db: Session = Depends(get_db)):
    return [
        ServiceItem(
            slug=s.slug, name=s.name, description=s.description, icon=s.icon
        )
        for s in nghiep_vu.danh_muc(db)
    ]


@router.post("/requests", status_code=201, response_model=ServiceRequestPublic)
@limiter.limit("20/hour")
def create_request(
    request: Request,
    body: ServiceRequestCreate,
    db: Session = Depends(get_db),
    claims: dict | None = Depends(auth.optional_user),
):
    if not _PHONE_RE.match(body.phone.strip()):
        raise HTTPException(status_code=422, detail="Số điện thoại không hợp lệ")
    uid = int(claims["sub"]) if claims else None
    item = nghiep_vu.tao_yeu_cau(db, body, user_id=uid)
    return ServiceRequestPublic(
        id=item.id,
        service_slug=item.service_slug,
        status=item.status,
        created_at=item.created_at,
    )


@router.get("/requests/mine")
def my_requests(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Yêu cầu dịch vụ của CHÍNH người đang đăng nhập.

    Trước đây chỉ admin xem được danh sách, nên khách gửi yêu cầu xong là mất
    dấu: không biết có ai nhận chưa, đã hẹn giờ nào. Route này đứng TRƯỚC
    `/requests/{id}` không có ở đây nhưng vẫn giữ quy ước thứ tự của file.
    """
    uid = int(claims["sub"])
    rows = nghiep_vu.danh_sach_cua_toi(db, user_id=uid)
    ten = {s.slug: s.name for s in db.query(Service).all()}
    return {"requests": [nghiep_vu.thanh_dict_cua_toi(r, ten) for r in rows]}


@router.get("/requests")
def admin_list_requests(
    status: str | None = Query(default=None),
    service_slug: str | None = Query(default=None),
    q: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    rows = nghiep_vu.danh_sach_admin(
        db, status=status, service_slug=service_slug, q=q, limit=limit, offset=offset
    )
    ten = {s.slug: s.name for s in db.query(Service).all()}
    return {"requests": [nghiep_vu.thanh_dict_admin(r, ten) for r in rows]}


@router.patch("/requests/{request_id}")
def admin_update_request(
    request_id: int,
    body: ServiceRequestUpdate,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    item = db.get(ServiceRequest, request_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy yêu cầu")

    # Đổi trạng thái (+ mốc liên hệ đầu tiên tự ghi) dùng CHUNG với Admin V2.
    partners_ops.update_service_request(
        item, status=body.status, scheduled_at=body.scheduled_at, admin_note=body.admin_note
    )

    db.commit()
    db.refresh(item)
    ten = {s.slug: s.name for s in db.query(Service).all()}
    return nghiep_vu.thanh_dict_admin(item, ten)
