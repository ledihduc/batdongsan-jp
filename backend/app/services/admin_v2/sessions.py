"""Phiên đăng nhập backoffice: token riêng `typ=admin` gắn `sid` trong DB.

Token admin KHÔNG dùng được cho API app thường (verify_token mặc định đòi
typ=auth) và ngược lại; thu hồi phiên có hiệu lực ngay request kế tiếp.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt
from sqlalchemy.orm import Session

from app import models
from app.config import settings

ADMIN_SESSION_HOURS = 12


def sign_admin_token(user_id: int, session_id: str, expires_at: datetime) -> str:
    now = datetime.now(timezone.utc)
    exp = expires_at.replace(tzinfo=timezone.utc)
    return jwt.encode(
        {
            "sub": str(user_id),
            "typ": "admin",
            "sid": session_id,
            "iat": int(now.timestamp()),
            "exp": int(exp.timestamp()),
        },
        settings.jwt_secret,
        algorithm="HS256",
    )


def open_session(db: Session, *, user_id: int, ip_hash: Optional[str], user_agent: Optional[str]) -> models.AdminSession:
    now = datetime.utcnow()
    s = models.AdminSession(
        id=str(uuid.uuid4()),
        user_id=user_id,
        created_at=now,
        expires_at=now + timedelta(hours=ADMIN_SESSION_HOURS),
        last_seen_at=now,
        # Vừa nhập mật khẩu xong = vừa xác thực lại.
        reauth_at=now,
        ip_hash=ip_hash,
        user_agent=(user_agent or "")[:300] or None,
    )
    db.add(s)
    db.flush()
    return s


def revoke_sessions(db: Session, *, user_id: int, by: Optional[int], reason: str, except_id: Optional[str] = None) -> int:
    now = datetime.utcnow()
    q = db.query(models.AdminSession).filter(
        models.AdminSession.user_id == user_id,
        models.AdminSession.revoked_at.is_(None),
        models.AdminSession.expires_at > now,
    )
    n = 0
    for s in q.all():
        if except_id and s.id == except_id:
            continue
        s.revoked_at = now
        s.revoked_by = by
        s.revoke_reason = reason[:300]
        n += 1
    db.flush()
    return n


def session_dict(s: models.AdminSession, current_id: Optional[str] = None) -> dict:
    from app.services.admin_v2.core import iso

    now = datetime.utcnow()
    state = "active"
    if s.revoked_at is not None:
        state = "revoked"
    elif s.expires_at <= now:
        state = "expired"
    return {
        "id": s.id,
        "state": state,
        "is_current": s.id == current_id,
        "created_at": iso(s.created_at),
        "last_seen_at": iso(s.last_seen_at),
        "expires_at": iso(s.expires_at),
        "revoked_at": iso(s.revoked_at),
        "revoke_reason": s.revoke_reason,
        "user_agent": s.user_agent,
    }
