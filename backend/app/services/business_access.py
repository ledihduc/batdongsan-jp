"""Business workspaces are available to every active account.

These modes do not change system roles. Each resource still enforces its own
ownership, assignment or delegation scope.
"""

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models


BUSINESS_MODES = ("customer", "sale", "owner")


def can_use_business_mode(user: models.User, mode: str) -> bool:
    return bool(user.is_active) and mode in BUSINESS_MODES


def require_business_user(db: Session, user_id: int) -> models.User:
    user = db.get(models.User, int(user_id))
    if user is None or not user.is_active:
        raise HTTPException(403, detail="Tài khoản không tồn tại hoặc đã bị vô hiệu hóa")
    return user
