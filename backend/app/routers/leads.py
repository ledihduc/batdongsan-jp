"""Lead 'gọi lại' nhẹ (redesign v2 — thu lead không cần login).

  POST /api/leads         — khách/đăng nhập đều gửi được (optional_user). Chỉ cần
                            Tên + SĐT. Tách khỏi RFQ báo giá thi công.
  GET  /api/admin/leads   — admin xem danh sách lead để gọi lại/remarketing.

KHÔNG dùng `from __future__ import annotations` (pydantic body).
"""

import re

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import auth, models
from app.database import get_db
from app.middleware.rate_limit import limiter

router = APIRouter(prefix="/api", tags=["leads"])

# Cùng khuôn với RFQ (construction) — chấp nhận 0…/ +84… , cho phân tách nhẹ.
_PHONE_RE = re.compile(r"^(?:\+?84|0)(?:\d[\s.\-]?){8,10}$")


class LeadBody(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    phone: str = Field(min_length=8, max_length=30)
    source: str = Field(default="unknown", max_length=50)
    context: str | None = Field(default=None, max_length=500)
    world: str | None = Field(default=None, max_length=20)
    province_code: str | None = Field(default=None, max_length=32)


@router.post("/leads", status_code=201)
@limiter.limit("20/hour")
def create_lead(
    request: Request,
    body: LeadBody,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.optional_user),
):
    if not _PHONE_RE.match(body.phone.strip()):
        raise HTTPException(status_code=422, detail="Số điện thoại không hợp lệ")
    uid = int(claims["sub"]) if claims else None
    lead = models.ContactLead(
        user_id=uid,
        name=body.name.strip()[:200],
        phone=body.phone.strip()[:50],
        source=(body.source or "unknown")[:50],
        context=(body.context or "").strip()[:500] or None,
        world=body.world,
        province_code=body.province_code,
        status="new",
    )
    db.add(lead)
    db.commit()
    db.refresh(lead)
    return {"id": lead.id, "status": lead.status}


@router.get("/admin/leads")
def list_leads(
    status: str = "",
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_admin),
):
    q = db.query(models.ContactLead)
    if status:
        q = q.filter(models.ContactLead.status == status)
    rows = (
        q.order_by(models.ContactLead.created_at.desc()).limit(500).all()
    )
    return {
        "leads": [
            {
                "id": l.id,
                "name": l.name,
                "phone": l.phone,
                "source": l.source,
                "context": l.context,
                "world": l.world,
                "province_code": l.province_code,
                "status": l.status,
                "user_id": l.user_id,
                "created_at": l.created_at.isoformat() if l.created_at else None,
            }
            for l in rows
        ]
    }
